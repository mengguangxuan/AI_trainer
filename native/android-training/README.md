# Android 原生实时训练基线

本目录是迁入团队移动端仓库的 Android 原型，用于在 Flutter 桥接完成前保持一份可独立构建、可真机运行的基线。

核心链路：

```text
CameraX → MediaPipe Pose Landmarker → ExerciseAnalyzer
        → 骨架和训练 HUD          → TrainingSessionController
        → 结构化事件日志           → SessionResult
```

当前支持：

- 深蹲 `squat`；
- 俯卧撑 `push_up`；
- 次数、阶段、角度和基础纠错；
- 前后摄像头；
- 单次训练的准备、训练、暂停、继续、完成和取消状态；
- 目标次数、真实次数和扣除暂停时间后的实际训练时长；
- 可由未来 Flutter Gateway 启动的 `TrainingActivity` 及 Activity result；
- 原始视频不上传；
- `motion.rep_completed` 和 `motion.form_event` Logcat 事件。

关键文件：

```text
app/src/main/java/com/google/mediapipe/examples/poselandmarker/
├── fragment/CameraFragment.kt
├── OverlayView.kt
├── PoseLandmarkerHelper.kt
├── TrainingActivity.kt
├── training/ExerciseAnalyzer.kt
├── training/session/TrainingSessionController.kt
└── training/bridge/TrainingBridgeContract.kt
```

模型已经包含在：

```text
app/src/main/assets/pose_landmarker_lite.task
```

构建方式见仓库根目录 `README.md`。详细算法、测试和限制见 `FITNESS_COACH_PROTOTYPE.md`。

本目录源自 Google MediaPipe Pose Landmarker Android 示例。合并到 Flutter 宿主时必须保留第三方许可证和原文件版权头。上游说明位于：

```text
../../third_party/mediapipe-samples/README.md
```

原生源码保留上游示例 namespace，Flutter 产品包通过 `android/trainingbridge` library 模块引用它；最终 APK 的 `applicationId` 仍由 Flutter 宿主控制。这样既保留第三方来源边界，也避免复制两套训练代码。
