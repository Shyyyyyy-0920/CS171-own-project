# RobotLab private dependency copies

These dependencies were copied once from the existing local HW2 dependency cache on 2026-11-05. The application configures and builds using only these private copies. None of the paths below is referenced by the build configuration or scripts.

| Private directory | Dependency | One-time local source |
| --- | --- | --- |
| `arietta/` | Arietta, revision pinned by HW2 to `2a427f2abd5341582f4f64a4b4b66806cab3998f` | `E:\CS171\ShanghaiTech-CS171\HW\CS171-HW2\build\CPM\arietta\a862` |
| `glfw/` | GLFW 3.5.1 | `E:\CS171\ShanghaiTech-CS171\HW\CS171-HW2\build\CPM\glfw\3bfe` |
| `glad/` | GLAD 2.0.8 generated C loader, OpenGL core 4.1, no extensions | `E:\CS171\ShanghaiTech-CS171\HW\CS171-HW2\build\gladsources\glad_gl_core_41` |

The Arietta and GLFW source files and their licenses are retained. `.git` metadata was excluded. Arietta tests and GLFW examples/docs/tests are retained as upstream source files but are disabled in this app's build.

Only GLAD's generated `include/` files and `src/gl.c` were copied; its original `args.txt`, generator environment, build files, and absolute output paths were not copied. `glad/LICENSE` is copied from the matching cached GLAD source at `HW\CS171-HW2\build\CPM\glad\49be\LICENSE` and includes the GLAD/Khronos notices. The generated files also retain their license notices.

The original `cmake/SetupGladPython.cmake` is retained in the app as copied historical project support. The new CMake configuration does not include or execute it. No Python environment, CPM source cache, network fetch, or original HW directory is needed to build this private app.
