# Prepare a private generator environment. Never install into the system Python.
# Python_EXECUTABLE is an output for glad; CS171_GLAD_PYTHON selects the host Python.
set(CS171_GLAD_PYTHON "" CACHE FILEPATH "Host Python 3.9+ executable used to create glad's virtual environment")

# Run on include, keeping temporary variables local and exporting only glad's interpreter.
block(SCOPE_FOR VARIABLES PROPAGATE Python_EXECUTABLE)
  set(venv "${CMAKE_CURRENT_BINARY_DIR}/glad-python")
  if (CMAKE_HOST_WIN32)
    set(python "${venv}/Scripts/python.exe")
  else ()
    set(python "${venv}/bin/python")
  endif ()

  # Serialize setup when two configure processes use the same build directory.
  file(LOCK "${CMAKE_CURRENT_BINARY_DIR}/glad-python.lock"
    GUARD FILE TIMEOUT 30 RESULT_VARIABLE lock_result)
  if (NOT lock_result STREQUAL "0")
    message(FATAL_ERROR
      "GLAD: Could not lock '${CMAKE_CURRENT_BINARY_DIR}/glad-python.lock': ${lock_result}\n"
      "Check build-directory permissions. If another configure is running, wait for it to finish and retry.")
  endif ()

  # Check isolation as well as executability before permitting any pip operation.
  set(check_venv [=[
import pathlib, sys
root = pathlib.Path(sys.argv[1]).resolve()
if sys.version_info < (3, 9) or sys.prefix == sys.base_prefix:
    raise RuntimeError("Expected a Python 3.9+ virtual environment")
if pathlib.Path(sys.prefix).resolve() != root:
    raise RuntimeError("Interpreter belongs to a different environment")
config = dict(line.split("=", 1) for line in (root / "pyvenv.cfg").read_text(encoding="utf-8").splitlines() if "=" in line)
config = {key.strip().lower(): value.strip().lower() for key, value in config.items()}
if config.get("include-system-site-packages") != "false":
    raise RuntimeError("The glad environment must not inherit system packages")
]=])
  execute_process(COMMAND "${python}" -I -c "${check_venv}" "${venv}"
    RESULT_VARIABLE valid OUTPUT_QUIET ERROR_QUIET TIMEOUT 15)
  if (NOT valid STREQUAL "0" OR CS171_GLAD_PYTHON)
    # Validate commands AND the path they report: launchers/shims are not the
    # interpreter that should create the environment. Do not resolve symlinks,
    # since doing so can change the meaning of a virtual-environment interpreter.
    set(probe [=[
import os, sys
if sys.version_info < (3, 9):
    raise RuntimeError("Python 3.9+ is required; found " + sys.version)
import venv, ensurepip
if not sys.executable:
    raise RuntimeError("Python did not report an executable path")
print(os.path.abspath(sys.executable))
]=])
    set(probe_environment "${CMAKE_COMMAND}" -E env
      --unset=PYLAUNCHER_ALLOW_INSTALL --unset=PYLAUNCHER_ALWAYS_INSTALL
      --unset=PYLAUNCHER_DRYRUN "PYTHON_MANAGER_AUTOMATIC_INSTALL=false")
    set(host_python "")
    set(attempts "")
    set(tried "")
    if (CS171_GLAD_PYTHON)
      # An explicit override must succeed; silently substituting another Python
      # would hide a configuration mistake.
      set(stages explicit)
    else ()
      set(stages cmake commands locations)
    endif ()

    foreach (stage IN LISTS stages)
      set(candidates "")
      if (stage STREQUAL "explicit")
        list(APPEND candidates "${CS171_GLAD_PYTHON}")
      elseif (stage STREQUAL "cmake")
        # Separate namespace from glad's Python_EXECUTABLE, which may be stale.
        # The generator runs on the host, even when compiling for another OS.
        set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
        find_package(Python3 3.9 QUIET COMPONENTS Interpreter)
        if (Python3_Interpreter_FOUND)
          list(APPEND candidates "${Python3_EXECUTABLE}")
        else ()
          string(APPEND attempts "\n  CMake FindPython3: no suitable interpreter found.")
        endif ()
      elseif (stage STREQUAL "commands")
        cmake_path(CONVERT "$ENV{PATH}" TO_CMAKE_PATH_LIST search_path NORMALIZE)
        if (CMAKE_HOST_WIN32)
          set(command_names py.exe python3.exe python.exe)
        else ()
          set(command_names python3 python)
        endif ()
        # Enumerate all PATH entries, so a broken shim cannot hide a later Python.
        foreach (name IN LISTS command_names)
          foreach (directory IN LISTS search_path)
            if (IS_ABSOLUTE "${directory}" AND EXISTS "${directory}/${name}")
              list(APPEND candidates "${directory}/${name}")
            endif ()
          endforeach ()
        endforeach ()
      else ()
        # Bounded searches only: GUI IDEs may not inherit shell/Conda PATH setup.
        set(roots "")
        foreach (env_name IN ITEMS VIRTUAL_ENV CONDA_PREFIX)
          if (NOT "$ENV{${env_name}}" STREQUAL "")
            list(APPEND roots "$ENV{${env_name}}")
          endif ()
        endforeach ()
        if (CMAKE_HOST_WIN32)
          set(user_directory "$ENV{USERPROFILE}")
          foreach (env_name IN ITEMS LOCALAPPDATA ProgramData ProgramFiles)
            if (NOT "$ENV{${env_name}}" STREQUAL "")
              foreach (distribution IN ITEMS miniconda3 anaconda3 miniforge3)
                list(APPEND roots "$ENV{${env_name}}/${distribution}")
              endforeach ()
              file(GLOB installations LIST_DIRECTORIES true
                "$ENV{${env_name}}/Programs/Python/Python3*"
                "$ENV{${env_name}}/Python3*")
              list(SORT installations COMPARE NATURAL ORDER DESCENDING)
              list(APPEND roots ${installations})
            endif ()
          endforeach ()
        else ()
          set(user_directory "$ENV{HOME}")
          list(APPEND roots /usr /usr/local /opt/local /opt/homebrew
            /opt/conda /opt/miniconda3 /opt/anaconda3 /opt/miniforge3)
          file(GLOB installations LIST_DIRECTORIES true
            "/opt/homebrew/opt/python@*" "/usr/local/opt/python@*"
            "/Library/Frameworks/Python.framework/Versions/3.*")
          list(SORT installations COMPARE NATURAL ORDER DESCENDING)
          list(APPEND roots ${installations})
        endif ()
        if (IS_ABSOLUTE "${user_directory}")
          foreach (distribution IN ITEMS miniconda3 anaconda3 miniforge3)
            list(APPEND roots "${user_directory}/${distribution}")
          endforeach ()
          if (CMAKE_HOST_WIN32)
            list(APPEND roots "${user_directory}/scoop/apps/python/current")
          else ()
            file(GLOB installations LIST_DIRECTORIES true
              "${user_directory}/.pyenv/versions/*"
              "${user_directory}/Library/Frameworks/Python.framework/Versions/3.*")
            list(SORT installations COMPARE NATURAL ORDER DESCENDING)
            list(APPEND roots ${installations})
          endif ()
        endif ()
        foreach (root IN LISTS roots)
          if (IS_ABSOLUTE "${root}")
            if (CMAKE_HOST_WIN32)
              list(APPEND candidates "${root}/python.exe" "${root}/Scripts/python.exe")
            else ()
              list(APPEND candidates "${root}/bin/python3" "${root}/bin/python")
              # Versioned-only packages (for example Homebrew python@3.13)
              # need not provide an unversioned python3 command.
              file(GLOB versioned_python LIST_DIRECTORIES false "${root}/bin/python3.*")
              list(SORT versioned_python COMPARE NATURAL ORDER DESCENDING)
              foreach (executable IN LISTS versioned_python)
                if (executable MATCHES "/python3\\.[0-9]+$")
                  list(APPEND candidates "${executable}")
                endif ()
              endforeach ()
            endif ()
          endif ()
        endforeach ()
      endif ()

      foreach (candidate IN LISTS candidates)
        cmake_path(CONVERT "${candidate}" TO_CMAKE_PATH_LIST candidate NORMALIZE)
        if (candidate IN_LIST tried)
          continue()
        endif ()
        list(APPEND tried "${candidate}")
        if (NOT IS_ABSOLUTE "${candidate}" OR NOT EXISTS "${candidate}" OR IS_DIRECTORY "${candidate}")
          if (stage STREQUAL "explicit")
            string(APPEND attempts "\n  '${candidate}': expected an existing absolute executable path.")
          endif ()
          continue()
        endif ()
        # These python.exe aliases can open the Microsoft Store. py.exe is safe
        # to probe with automatic installation disabled above.
        string(TOLOWER "${candidate}" candidate_lower)
        if (CMAKE_HOST_WIN32 AND candidate_lower MATCHES "/microsoft/windowsapps/python[0-9.]*\\.exe$")
          string(APPEND attempts "\n  '${candidate}': skipped Windows Store alias; select the installed Python executable.")
          continue()
        endif ()
        set(launcher_args "")
        get_filename_component(candidate_name "${candidate_lower}" NAME)
        if (CMAKE_HOST_WIN32 AND candidate_name STREQUAL "py.exe")
          set(launcher_args -3)
        endif ()
        execute_process(COMMAND ${probe_environment} "${candidate}" ${launcher_args} -I -X utf8 -c "${probe}"
          RESULT_VARIABLE probe_result OUTPUT_VARIABLE actual_python ERROR_VARIABLE probe_error
          OUTPUT_STRIP_TRAILING_WHITESPACE ENCODING UTF-8 TIMEOUT 15)
        if (probe_result STREQUAL "0" AND IS_ABSOLUTE "${actual_python}"
          AND EXISTS "${actual_python}" AND NOT IS_DIRECTORY "${actual_python}")
          execute_process(COMMAND ${probe_environment} "${actual_python}" -I -X utf8 -c "${probe}"
            RESULT_VARIABLE probe_result OUTPUT_QUIET ERROR_VARIABLE probe_error
            ENCODING UTF-8 TIMEOUT 15)
          if (probe_result STREQUAL "0")
            set(host_python "${actual_python}")
            message(STATUS "GLAD: Found host Python via ${stage}: ${host_python}")
            break()
          endif ()
        endif ()
        string(STRIP "${probe_error}" probe_error)
        string(SUBSTRING "${probe_error}" 0 1000 probe_error)
        string(APPEND attempts "\n  '${candidate}': result=${probe_result}; expected a runnable Python 3.9+ with venv/ensurepip. ${probe_error}")
      endforeach ()
      if (host_python)
        break()
      endif ()
    endforeach ()

    if (NOT host_python)
      message(FATAL_ERROR
        "GLAD: No usable host Python 3.9+ with venv and ensurepip was found.\n"
        "Install Python (Debian/Ubuntu may also need python3-venv), then reload CMake.\n"
        "If discovery fails, set -DCS171_GLAD_PYTHON:FILEPATH=<absolute path to python>\n"
        "in your CMake options (both CLion profiles). This is a host executable, not a target/sysroot Python.\n"
        "Discovery results:${attempts}")
    endif ()

    if (valid STREQUAL "0")
      # A new explicit selection must not be silently ignored or overlaid onto
      # an environment created by another Python installation/version.
      set(base_identity "import json, os, sys; print(json.dumps([os.path.normcase(os.path.realpath(sys.base_prefix)), sys.implementation.name, list(sys.version_info[:3])]))")
      execute_process(COMMAND "${host_python}" -I -X utf8 -c "${base_identity}"
        RESULT_VARIABLE host_result OUTPUT_VARIABLE host_identity ERROR_VARIABLE host_error
        OUTPUT_STRIP_TRAILING_WHITESPACE ENCODING UTF-8 TIMEOUT 15)
      execute_process(COMMAND "${python}" -I -X utf8 -c "${base_identity}"
        RESULT_VARIABLE env_result OUTPUT_VARIABLE env_identity ERROR_VARIABLE env_error
        OUTPUT_STRIP_TRAILING_WHITESPACE ENCODING UTF-8 TIMEOUT 15)
      if (NOT host_result STREQUAL "0" OR NOT env_result STREQUAL "0")
        message(FATAL_ERROR "GLAD: Could not compare the selected Python with the existing environment.\n${host_error}\n${env_error}")
      endif ()
      if (NOT host_identity STREQUAL env_identity)
        message(FATAL_ERROR
          "GLAD: CS171_GLAD_PYTHON selects a different Python from the existing environment.\n"
          "Remove only '${venv}' and reload CMake to apply the new selection.")
      endif ()
    endif ()
  endif ()

  if (NOT valid STREQUAL "0")
    message(STATUS "GLAD: Creating Python environment at ${venv}")
    execute_process(COMMAND "${host_python}" -I -X utf8 -m venv "${venv}"
      RESULT_VARIABLE created OUTPUT_VARIABLE output ERROR_VARIABLE error ENCODING UTF-8 TIMEOUT 120)
    if (NOT created STREQUAL "0")
      message(FATAL_ERROR
        "GLAD: Could not create the virtual environment (${created}).\n"
        "Ensure Python includes venv and ensurepip (Debian/Ubuntu: install python3-venv).\n"
        "For an incomplete environment, remove only '${venv}' and reload CMake.\n${output}\n${error}")
    endif ()
    execute_process(COMMAND "${python}" -I -c "${check_venv}" "${venv}"
      RESULT_VARIABLE valid OUTPUT_QUIET ERROR_VARIABLE error TIMEOUT 15)
    if (NOT valid STREQUAL "0")
      message(FATAL_ERROR
        "GLAD: The environment is not a working isolated Python (${valid}).\n"
        "Remove only '${venv}' and reload CMake.\n${error}")
    endif ()
  endif ()

  # Keep version checks and installation requirements in one self-contained list.
  set(requirements "Jinja2==3.1.6" "MarkupSafe==3.0.3")
  set(check_packages [=[
import jinja2, markupsafe, pathlib, sys
from importlib.metadata import version
root = pathlib.Path(sys.prefix).resolve()
for module in (jinja2, markupsafe):
    if not pathlib.Path(module.__file__).resolve().is_relative_to(root):
        raise RuntimeError("Dependency was imported from outside the glad environment")
for requirement in sys.argv[1:]:
    name, expected = requirement.split("==")
    if version(name) != expected:
        raise RuntimeError("Unexpected version of " + name)
]=])
  execute_process(COMMAND "${python}" -I -c "${check_packages}" ${requirements}
    RESULT_VARIABLE packages_valid OUTPUT_QUIET ERROR_QUIET TIMEOUT 15)
  if (NOT packages_valid STREQUAL "0")
    execute_process(COMMAND "${python}" -I -m pip --version
      RESULT_VARIABLE pip_valid OUTPUT_QUIET ERROR_QUIET TIMEOUT 15)
    if (NOT pip_valid STREQUAL "0")
      message(STATUS "GLAD: Restoring pip in the private environment")
      execute_process(COMMAND "${python}" -I -X utf8 -m ensurepip --upgrade
        RESULT_VARIABLE pip_restored OUTPUT_VARIABLE output ERROR_VARIABLE error
        ENCODING UTF-8 TIMEOUT 120)
      execute_process(COMMAND "${python}" -I -m pip --version
        RESULT_VARIABLE pip_valid OUTPUT_QUIET ERROR_VARIABLE pip_error TIMEOUT 15)
      if (NOT pip_restored STREQUAL "0" OR NOT pip_valid STREQUAL "0")
        message(FATAL_ERROR
          "GLAD: Could not restore pip (${pip_restored}). Remove only '${venv}' and reload CMake.\n"
          "${output}\n${error}\n${pip_error}")
      endif ()
    endif ()
    message(STATUS "GLAD: Installing generator dependencies (first setup requires a package source)")
    # Keep index/proxy settings usable for school networks, but prevent common
    # pip destination overrides from redirecting installation outside this venv.
    execute_process(
      COMMAND "${CMAKE_COMMAND}" -E env --unset=PIP_TARGET --unset=PIP_PREFIX
      "${python}" -I -X utf8 -m pip --disable-pip-version-check --require-virtualenv
      install --no-user --prefix "${venv}" --no-input --timeout 30 --retries 1
      --force-reinstall --no-deps
      ${requirements}
      RESULT_VARIABLE installed OUTPUT_VARIABLE output ERROR_VARIABLE error ENCODING UTF-8 TIMEOUT 180)
    if (NOT installed STREQUAL "0")
      message(FATAL_ERROR
        "GLAD: Dependency installation failed (${installed}).\n"
        "Check your network, proxy or pip package index, then reload CMake.\n"
        "For offline installation, use PIP_NO_INDEX=1 and PIP_FIND_LINKS=<local wheel directory>.\n"
        "If pip is missing, remove only '${venv}' and reload CMake.\n${output}\n${error}")
    endif ()
    execute_process(COMMAND "${python}" -I -c "${check_packages}" ${requirements}
      RESULT_VARIABLE packages_valid OUTPUT_QUIET ERROR_VARIABLE error TIMEOUT 15)
    if (NOT packages_valid STREQUAL "0")
      message(FATAL_ERROR "GLAD: Installed packages failed validation. Remove only '${venv}' and reload CMake.\n${error}")
    endif ()
  endif ()

  # Deliberately override stale legacy Python_EXECUTABLE values in this scope;
  # do not write a machine-specific path into the project's source or cache.
  set(Python_EXECUTABLE "${python}")
  message(STATUS "GLAD: Using ${python}")
endblock()
