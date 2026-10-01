# AI 健身教练移动端

这是 C、D 两端共同维护的移动端集成仓库。最终形态以 Flutter 产品工程为主，Android 原生模块负责 CameraX、MediaPipe、动作分析和训练结果回传。

## 当前状态

- 已迁入可构建的 Android 实时训练原型；
- 已迁入 `pose_landmarker_lite.task`；
- 已迁入动作分析器、测试、协议和架构文档；
- 已实现原生 `TrainingActivity`、训练会话生命周期以及 `SessionResult` 返回；
- 已实现暂停、继续、完成和取消，`duration_ms` 只统计实际训练时间；
- 已保留 Google MediaPipe 示例的 Apache 2.0 许可证和来源说明；
- 当前尚未收到 D 的 Flutter 工程和 `MOBILE_INTEGRATION_PLAN.md`；
- `TrainingLaunchArgs` 和 `SessionResult` 原生接口已经预留，实际 Flutter MethodChannel 等 D 端工程到位后接入；
- iOS 因当前缺少 macOS/Xcode 硬件条件，不在本阶段范围内。

## 目录

```text
ai_fitness_coach/
├── docs/
│   ├── architecture/          架构和 C 端交接文档
│   └── contracts/             通信协议与 C/D 对齐文档
├── native/
│   └── android-training/      当前可独立构建的 Android 训练原型
└── third_party/
    └── mediapipe-samples/     上游来源和许可证
```

D 端 Flutter 工程进入仓库后，预期增加：

```text
├── pubspec.yaml
├── lib/                       Flutter 页面、Gateway 和业务状态
├── android/                   Flutter Android 宿主及迁入后的训练模块
├── assets/models/             Flutter 管理的共享模型（如最终采用）
└── test/
```

在桥接完成前，`native/android-training` 保持为可运行基线。不要直接删除它；先完成 Flutter 单 APK 的真机验收，再决定是否将其缩减为参考目录。

## Android 原型构建

Windows PowerShell：

```powershell
cd native\android-training
powershell -ExecutionPolicy Bypass -File .\build_local.ps1
```

或者在已经配置好 JDK 21 和 Android SDK 的环境中运行：

```powershell
.\gradlew.bat --no-daemon testDebugUnitTest assembleDebug
```

APK 输出到：

```text
native/android-training/app/build/outputs/apk/debug/app-debug.apk
```

## 首轮集成目标

```text
Flutter 首页
    → TrainingGateway.startTraining(args)
    → Android TrainingActivity
    → CameraFragment + ExerciseAnalyzer
    → SessionResult
    → Flutter 总结页
```

原生侧的 `squat` 和 `push_up` 共用同一接口。当前先完成 Android 独立训练闭环和真机验收，D 端工程到位后再接通 Flutter 首页与总结页。

## 提交规则

- `main` 必须保持可构建、可演示；
- C 使用 `feature/android-training-bridge`；
- D 使用 `feature/flutter-product-pages`；
- 不提交构建缓存、APK、`local.properties`、密钥、签名文件或真实 Token；
- 修改桥接字段时，同时更新 `docs/contracts/`；
- 保留第三方版权头和 `third_party/mediapipe-samples/LICENSE`。
