# 构建依赖与来源

本工程使用私有源码副本，默认配置、编译不联网，也不使用原作业的构建缓存。`vendor` 保留各自许可证；GLAD 已生成 C 源码，构建无需 Python。

| 依赖 | 版本 / 标识 | 本项目位置 |
|---|---|---|
| Arietta | HW2 固定版本 `2a427f2abd5341582f4f64a4b4b66806cab3998f` | `vendor/arietta`，C++23 头文件库 |
| GLFW | HW2 使用的 3.5.1 缓存源码 | `vendor/glfw`，静态构建 |
| GLAD | HW2 使用的 v2.0.8 生成器所生成的 OpenGL 4.1 Core 加载器 | `vendor/glad/include`、`vendor/glad/src/gl.c` |

一次性复制来源为 HW2 的 `build/CPM/arietta/a862`、`build/CPM/glfw/3bfe`、`build/gladsources/glad_gl_core_41`，以及 `build/CPM/glad/49be/LICENSE`。这些路径只是来源记录；新项目的 CMake 不引用它们。

初始项目源码、shader 和曲面资源复制自用户自己的 HW2；自由相机沿用用户 HW1 的移动/鼠标约定，准星 shader 来自用户自己的 HW1。原课程源码声明与 agent 指引保留，用作个人学习；未复制原 `.git`、可执行文件、CMakeCache、报告或 Python 虚拟环境。

## 本机工具

默认使用 `E:\Cmake\bin\cmake.exe`、`E:\mingw64\bin\gcc.exe`、`g++.exe` 和 `ninja.exe`。脚本参数可覆盖：

```powershell
powershell -ExecutionPolicy Bypass -File .\build.ps1 -Test
powershell -ExecutionPolicy Bypass -File .\build.ps1 -Configuration Release -BuildDirectory build-release
powershell -ExecutionPolicy Bypass -File .\run.ps1 -BuildDirectory build-release
```

可选参数还有 `-CMakeExe`、`-CCompiler`、`-CXXCompiler`、`-MakeProgram`、`-RuntimeDirectory` 和 `-Jobs`。CMake 要求 C++23 编译器；Windows 窗口需要 OpenGL 4.1。

MinGW 的 `libgcc_s_seh-1.dll`、`libstdc++-6.dll`、`libwinpthread-1.dll` 在链接后复制到新可执行文件旁。脚本仅暂时调整当前进程 PATH，结束时恢复，不修改系统环境变量。

`build/bin` 包含应用、运行库、资源与 shader，程序在 Windows 优先从自身可执行文件旁查找资源。`run.ps1` 也将工作目录设为该目录；按 P 的截图默认保存在那里。
