cmake_minimum_required(VERSION 3.25.2)
project(RobotLab LANGUAGES C CXX)

# Keep generated files in a private build directory inside this app.
set(_robotlab_source_root "${CMAKE_SOURCE_DIR}")
cmake_path(IS_PREFIX _robotlab_source_root "${CMAKE_BINARY_DIR}" NORMALIZE _robotlab_build_is_private)
if(NOT _robotlab_build_is_private OR CMAKE_SOURCE_DIR STREQUAL CMAKE_BINARY_DIR)
  message(FATAL_ERROR "Use a separate build directory inside the app, for example: cmake -S . -B build")
endif()

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

set(_robotlab_bin "${CMAKE_BINARY_DIR}/bin")
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${_robotlab_bin}")
foreach(_robotlab_config DEBUG RELEASE RELWITHDEBINFO MINSIZEREL)
  set(CMAKE_RUNTIME_OUTPUT_DIRECTORY_${_robotlab_config} "${_robotlab_bin}")
endforeach()

# All dependencies are private source copies. No downloads or Python generator.
set(ARIETTA_ENABLE_TESTING OFF CACHE BOOL "Build Arietta tests" FORCE)
set(GLFW_BUILD_DOCS OFF CACHE BOOL "Build GLFW documentation" FORCE)
set(GLFW_BUILD_EXAMPLES OFF CACHE BOOL "Build GLFW examples" FORCE)
set(GLFW_BUILD_TESTS OFF CACHE BOOL "Build GLFW tests" FORCE)
set(GLFW_INSTALL OFF CACHE BOOL "Install GLFW" FORCE)
set(GLFW_LIBRARY_TYPE STATIC CACHE STRING "GLFW library type" FORCE)
add_subdirectory(vendor/arietta)
add_subdirectory(vendor/glfw)

add_library(glad_gl_core_41 STATIC vendor/glad/src/gl.c)
target_include_directories(glad_gl_core_41 PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}/vendor/glad/include")
set_target_properties(glad_gl_core_41 PROPERTIES C_STANDARD 99 C_STANDARD_REQUIRED ON)

file(GLOB_RECURSE ROBOTLAB_SOURCES CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/src/*.cpp")
add_executable(RobotLab ${ROBOTLAB_SOURCES})
target_include_directories(RobotLab PRIVATE include)
target_compile_features(RobotLab PRIVATE cxx_std_23)
target_compile_definitions(RobotLab PRIVATE GLFW_INCLUDE_NONE)
target_link_libraries(RobotLab PRIVATE Arietta glad_gl_core_41 glfw)
if(WIN32)
  target_link_libraries(RobotLab PRIVATE imm32)
endif()
target_compile_options(RobotLab PRIVATE $<$<CXX_COMPILER_ID:MSVC>:/utf-8>)

# Always refresh resources, including builds that only changed a shader/asset.
add_custom_target(RobotLabResources ALL
  COMMAND "${CMAKE_COMMAND}" -E make_directory "${_robotlab_bin}"
  COMMAND "${CMAKE_COMMAND}" -E copy_directory
    "${CMAKE_CURRENT_SOURCE_DIR}/assets" "${_robotlab_bin}/assets"
  COMMAND "${CMAKE_COMMAND}" -E copy_directory
    "${CMAKE_CURRENT_SOURCE_DIR}/shaders" "${_robotlab_bin}/shaders"
  COMMENT "Copying RobotLab assets and shaders to the private runtime directory"
  VERBATIM)
add_dependencies(RobotLab RobotLabResources)

get_filename_component(_robotlab_compiler_bin "${CMAKE_CXX_COMPILER}" DIRECTORY)
set(ROBOTLAB_RUNTIME_DIR "${_robotlab_compiler_bin}" CACHE PATH "Directory containing the selected MinGW runtime DLLs")
option(ROBOTLAB_COPY_MINGW_RUNTIME "Copy MinGW runtime DLLs next to executables" ON)
function(robotlab_copy_runtime target)
  if(WIN32 AND MINGW AND ROBOTLAB_COPY_MINGW_RUNTIME)
    foreach(_robotlab_dll libgcc_s_seh-1.dll libstdc++-6.dll libwinpthread-1.dll)
      if(EXISTS "${ROBOTLAB_RUNTIME_DIR}/${_robotlab_dll}")
        add_custom_command(TARGET ${target} POST_BUILD
          COMMAND "${CMAKE_COMMAND}" -E copy_if_different
            "${ROBOTLAB_RUNTIME_DIR}/${_robotlab_dll}" "$<TARGET_FILE_DIR:${target}>"
          VERBATIM)
      else()
        message(WARNING "Runtime DLL not found: ${ROBOTLAB_RUNTIME_DIR}/${_robotlab_dll}")
      endif()
    endforeach()
  endif()
endfunction()
robotlab_copy_runtime(RobotLab)

include(CTest)
if(BUILD_TESTING)
  add_executable(CameraChecks tests/CameraChecks.cpp src/Camera.cpp)
  target_include_directories(CameraChecks PRIVATE include)
  target_link_libraries(CameraChecks PRIVATE Arietta)
  set_target_properties(CameraChecks PROPERTIES RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/tests")
  foreach(_robotlab_config DEBUG RELEASE RELWITHDEBINFO MINSIZEREL)
    set_target_properties(CameraChecks PROPERTIES
      RUNTIME_OUTPUT_DIRECTORY_${_robotlab_config} "${CMAKE_BINARY_DIR}/tests")
  endforeach()
  target_compile_options(CameraChecks PRIVATE $<$<CXX_COMPILER_ID:MSVC>:/utf-8>)
  robotlab_copy_runtime(CameraChecks)
  add_test(NAME CameraChecks COMMAND $<TARGET_FILE:CameraChecks>)
endif()
