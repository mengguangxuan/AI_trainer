# AI 健身教练端侧测试版

这是在 MediaPipe Pose Landmarker Android 示例上扩展的 C 端原型。它的目的不是完成最终产品界面，而是尽快验证下面这条核心链路：

```text
摄像头 → MediaPipe 33 个姿态关键点 → 本地动作状态机
       → 屏幕即时反馈              → 结构化协议事件
```

原始图片和视频不会在这条链路中上传。当前也没有接入云端 WebSocket；协议事件先写到 Logcat，待 Agent 组确定服务器地址、鉴权和会话字段后，再接传输适配器。

## 已实现

- CameraX 实时摄像头预览；
- MediaPipe Pose Landmarker Lite 端侧推理；
- 33 点骨架覆盖显示，并隐藏低置信度点和连线；
- 深蹲与俯卧撑切换；
- 关节角度指数平滑；
- 选择可见度更高的完整单侧身体计算角度，避免遮挡侧污染结果；
- 按输入画面宽高修正归一化坐标的角度畸变；
- 连续 5 帧确认动作阶段，避免单帧抖动；
- 必须先确认起始位，再完成“最低点 → 起始位”后计数；
- 连续丢失关键点时取消未完成动作，避免重新入镜误计数；
- 深蹲躯干倾斜采用肩—髋向量相对竖直方向的夹角；
- 深蹲幅度、躯干倾斜、俯卧撑幅度、身体直线的基础提示；
- 重置计数、前后摄像头翻转；
- `motion.rep_completed` 和 `motion.form_event` JSON 日志；
- 错误提示采用开始/结束事件，不按摄像头帧率重复输出。

## 重要边界

当前阈值是用于打通工程链路的经验默认值，不代表已经完成运动医学验证或个体化标定。特别是单目 2D 姿态会受到拍摄角度、遮挡和透视影响，因此：

- 深蹲和俯卧撑应尽量侧面拍摄；
- 第一版只判断容易观测的角度，不判断膝盖内扣等强依赖正面机位的错误；
- 比赛演示前需要用不同身高、机位和动作速度的视频重新标定阈值；
- 后续应把“是否可观测”与“动作正确”严格区分。

## 关键文件

- `training/ExerciseAnalyzer.kt`：与 Android、MediaPipe 解耦的动作分析和事件生成；
- `fragment/CameraFragment.kt`：摄像头、MediaPipe 结果和训练界面的连接层；
- `res/layout/fragment_camera.xml`：训练 HUD；
- `tools/ExerciseAnalyzerSmokeCheck.kt`：不需要 Gradle 和网络的算法冒烟测试；
- `verify_algorithm.ps1`：离线编译并运行冒烟测试。

## 离线验证算法

在 PowerShell 中进入本目录后运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\verify_algorithm.ps1
```

正常结果：

```text
ExerciseAnalyzer smoke checks passed
```

该验证使用 `E:\Android\Studio\Android_studio` 中已经落盘的 Kotlin 编译器和 JBR，不需要 Gradle，也不会下载依赖。

## 构建 APK

现有 SDK 已包含 API 35、Build Tools 35 和 ADB。项目配置为：

- Android Gradle Plugin 8.7.3；
- Gradle 8.9；
- compileSdk / targetSdk 35；
- minSdk 24；
- MediaPipe Tasks Vision 1.0.0。

Android 官方兼容矩阵中，AGP 8.7 对应 Gradle 8.9 和最高 API 35。Lite 姿态模型已经放入 `app/src/main/assets`，构建时不再联网下载模型。首次构建仍需要完整的 Gradle 8.9，以及从 Maven 下载 AndroidX、CameraX、Material 和 MediaPipe 代码依赖。

```powershell
powershell -ExecutionPolicy Bypass -File .\build_local.ps1
```

完整且经过官方 SHA-256 校验的 Gradle 8.9 已放在工作区 `app/.tools/gradle-8.9-complete`，构建脚本会直接使用它；已经下载的 Maven 依赖也会从 `app/.gradle-user-home` 续用。`E:\Android\archives` 下原来的 Gradle 压缩包与解压目录仍然残缺，不要使用。

APK 成功生成后：

```powershell
& 'E:\Android\sdk\platform-tools\adb.exe' install -r '.\app\build\outputs\apk\debug\app-debug.apk'
& 'E:\Android\sdk\platform-tools\adb.exe' logcat -s FitnessCoachEvent:I
```

第二条命令可以查看准备发送给后端的结构化事件。日志中的 `session_id` 当前固定为 `local-prototype`，正式联调时必须由会话层注入真实值。

## 下一步

1. 在已安装最新 APK 的真机上验收两个动作按钮、具名角度和新版计数状态机；
2. 分别录制 10 次标准动作和常见错误动作；
3. 根据误计数情况调整阈值与稳定帧数；
4. 给 `ExerciseAnalyzer` 外面增加会话层，补齐组次、持续时间和置信度；
5. 再把事件接入项目的 WebSocket 协议适配器；
6. 最后封装成稳定的状态接口或 Flutter Platform Channel，D 端只消费状态与事件，不接触摄像头帧。
