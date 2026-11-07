# 重启零号实验室：独立实践工程

起点是你自己的 HW2，加入 HW1 的自由相机和绿色中心准星。原 HW1/HW2 不参与本项目的配置、构建或运行；源文件、曲面数据和第三方依赖均已有独立副本。

当前版本仍然显示一个曲面展品。接下来由你逐步完成多物体场景和工作台，第一关见 [FIRST_STEP.md](FIRST_STEP.md)。长期路线见 [项目设计](../PROJECT.md) 与 [观察舱深化路线](../TO_A.md)。

## 构建与启动

在 PowerShell 运行：

```powershell
Set-Location 'E:\CS171\output\robot-lab\app'
powershell -ExecutionPolicy Bypass -File .\build.ps1
powershell -ExecutionPolicy Bypass -File .\run.ps1
```

构建脚本的工具选择和离线依赖说明见 [DEPENDENCIES.md](DEPENDENCIES.md)。不需要重新下载窗口库或生成 GLAD。用 IDE 打开本目录的 `CMakeLists.txt` 即可；请使用本项目自己的 `build`，不要选择原作业的构建目录。

## 操作

| 输入 | 行为 |
|---|---|
| W / S | 沿当前视线前进 / 后退；抬头前进会升高，与 HW1 一致 |
| A / D | 向观察方向的左 / 右侧移 |
| 移动鼠标 | 直接转头，无需按键；灵敏度沿用 HW1 的每单位 0.1 度 |
| Tab | 释放 / 隐藏并捕获鼠标；释放时暂停相机输入，隐藏中心准星 |
| 1–4 | 切换现有曲面模型，并重新构图 |
| R | 重置相机到当前模型的初始构图 |
| N | 法线颜色 / Blinn–Phong |
| F1 | 线框；原 HW2 的 W 已让给前进 |
| F2 | 控制网与控制点 |
| 右键拖动 | 先按 Tab 释放鼠标，再编辑控制点；可先用 F2 显示它们 |
| M / B / G | 保留 HW2 的求值/细分、B-spline 和 GPU 曲面细分切换 |
| [ / ] | 改变网格分辨率；原 HW2 距离自适应逻辑仍会调整它 |
| F | 背面剔除 |
| P | 在当前工作目录保存 PPM 截图 |
| Esc | 退出 |

Q/E/Z/C 不改变视角；左键不再环绕物体。准星与 HW1 相同，是屏幕中心的绿色 3 像素点。移动速度沿用 6 世界单位/秒，多方向按键直接叠加；俯仰限制为 ±89 度。没有加入 Space/Ctrl 升降键。

## 从哪里读代码

- [Camera.hpp](include/Camera.hpp) / [Camera.cpp](src/Camera.cpp)：相机位置、朝向、移动与观察/投影矩阵。
- [Main.cpp](src/Main.cpp)：`OnMouseMove`、`CaptureMouse` 和每帧 WASD 输入，随后绘制曲面。失焦时暂停输入，恢复捕获时跳过首个鼠标位移，帧时间最多计 0.05 秒以避免停顿后的大跳。
- [Crosshair.cpp](src/Crosshair.cpp)：最后绘制屏幕中心点，并恢复使用过的 OpenGL 状态。
- [Mesh.hpp](include/Mesh.hpp)：CPU 的 `MeshData` 与 GPU 的 `Mesh`。它们是下一关区分“几何”与“场景物体”的起点。
- [Surface.vert](shaders/Surface.vert)：目前直接使用世界坐标，尚未接入每个物体的 `model` 矩阵。

## 可重复验证

```powershell
Set-Location 'E:\CS171\output\robot-lab\app'
ctest --test-dir .\build --output-on-failure
New-Item -ItemType Directory -Force .\screenshots | Out-Null
.\build\bin\RobotLab.exe --hidden --phong --size 1280 720 --screenshot .\screenshots\camera-base.ppm
```

`--hidden --frames 3` 可用于有限帧启动检查。截图与单元检查不能代替你实际用 WASD、鼠标和 Tab 体验操作；验证记录见 [VALIDATION.md](VALIDATION.md)。
