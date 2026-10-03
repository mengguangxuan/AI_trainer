# AI 健身教练移动端（C + D 集成仓库）

C、D 两端共同维护的移动端集成仓库。最终形态以 Flutter 产品工程为主，Android 原生模块负责 CameraX、MediaPipe、动作分析和训练结果回传。

## 当前状态

- **D 端（本分支 feature/flutter-product-pages）**：Flutter 产品工程已合入，画像/首页/计划/饮食/总结/历史全流程可用，`MockTrainingGateway` 模拟训练闭环已在小米 15 Pro（Android 16）真机验证 9/9 项通过（证据见 `docs/validation-evidence/`）。
- **C 端（main）**：可独立构建的 Android 实时训练原型（MediaPipe 姿态识别 + 深蹲/俯卧撑计数纠错）位于 `native/android-training/`。
- **尚未完成**：Flutter MethodChannel 桥接（`NativeTrainingGateway` Dart 侧已就绪）、真实训练闭环、Agent 接口。
- 桥接协议字段见 `docs/contracts/training_bridge_v1_draft.md` 与 `docs/MOBILE_INTEGRATION_PLAN.md`，最终以双方确认后冻结版本为准。

## 目录

```text
ai_fitness_coach/
├── docs/
│   ├── architecture/          架构和 C 端交接文档
│   ├── contracts/             通信协议与 C/D 对齐文档
│   ├── validation-evidence/   D 端验收截图（Web + 真机）
│   └── MOBILE_INTEGRATION_PLAN.md  整合决策与验收排期
├── lib/                       D 的 Flutter 页面、Gateway 和业务状态
├── android/                   Flutter Android 宿主
├── test/                      D 的单元与桥接边界测试
├── native/
│   └── android-training/      C 的可独立构建 Android 训练原型（基线，勿删）
└── third_party/
    └── mediapipe-samples/     上游来源和许可证
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

第一轮先打通 `squat`；验收通过后，同一接口开放 `push_up`。

## D 端 Flutter 工程运行

```powershell
flutter pub get
flutter analyze        # 当前：No issues found
flutter test           # 当前：5/5 通过
flutter devices
flutter run -d <设备ID>
```

依赖：Flutter 3.47.5 / Dart 3.13.4（要求 Dart ≥3.9）。**注意：工程需与 Flutter 插件缓存（PUB_CACHE）位于同一磁盘分区**，否则 Kotlin 增量编译跨盘符会失败（Kotlin "different roots" 错误）；国内网络下 Gradle wrapper 已配置腾讯镜像。

D 端真机验收要点（已在小米 15 Pro 通过）：画像保存 → 首页计划 → 模拟训练 → 总结 → 历史 → 强杀重启数据保留 → 取消不计入完成 → 勾选当前不适后训练入口消失。详见 `docs/VALIDATION.md`。

## C 端 Android 原型构建

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

在桥接完成前，`native/android-training` 保持为可运行基线。不要直接删除它；先完成 Flutter 单 APK 的真机验收，再决定是否将其缩减为参考目录。

## 提交规则

- `main` 必须保持可构建、可演示；
- C 使用 `feature/android-training-bridge`；
- D 使用 `feature/flutter-product-pages`；
- 不提交构建缓存、APK、`local.properties`、密钥、签名文件或真实 Token；
- 修改桥接字段时，同时更新 `docs/contracts/`；
- 保留第三方版权头和 `third_party/mediapipe-samples/LICENSE`。

## D 端原 README（独立原型时期）

<details>
<summary>历史记录：D 模块独立原型说明（已并入本仓库）</summary>

这是一个**独立的 Flutter 原型源码**，用于在没有团队仓库的情况下先完成 D 负责的非实时产品流程。已在真实 Flutter 工具链下完成编译、静态分析、单元测试与真机验收。

已实现：首次画像填写与修改（本机保存、重启恢复）；首页、今日计划、饮食建议、历史四个入口；计划中的深蹲目标通过 `TrainingLaunchArgs` 交给 `TrainingGateway`；`MockTrainingGateway` 返回完成或取消两种模拟结果；总结、历史、本地连续训练天数；取消训练不计入完成；有当前不适时模板不自动提供训练入口；未知错误码不编造解释；`CoachRepository` 抽象接口供 Agent B 的真实服务实现替换。

所有模板和模拟训练在界面标明来源。**没有实现摄像头、MediaPipe、WebSocket、真实 Agent API 或正式训练评分。**

| 文件或目录 | 内容与负责人 |
|---|---|
| `lib/core/models/user_profile_snapshot.dart` | D 输入的结构化画像，跨组字段需共同确认 |
| `lib/core/models/training_launch_args.dart` | D → C 的训练启动参数草案 |
| `lib/core/models/session_result.dart` | C → D 的训练结果草案，允许缺少未测量字段 |
| `lib/core/models/training_plan.dart`、`nutrition_advice.dart` | D 展示计划与饮食的最小对象 |
| `lib/core/theme/app_theme.dart` | D 所有的全局颜色和组件样式起点 |
| `lib/features/product/` | 画像、首页、计划、饮食、历史、总结及 D 产品入口 |
| `lib/features/training_contract/` | C 实现的训练桥接接口 + Dart 侧原生适配器 |
| `lib/mocks/mock_training_gateway.dart` | 供 D 并行开发的模拟训练页面 |
| `docs/` | 待确认接口、队友交接及 ZCode 指令 |

</details>
