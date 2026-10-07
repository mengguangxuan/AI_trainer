# AI 健身教练移动端（C + D 集成仓库）

C、D 两端共同维护的移动端集成仓库。最终形态以 Flutter 产品工程为主，Android 原生模块负责 CameraX、MediaPipe、动作分析和训练结果回传。

## 当前状态

- D 端 Flutter 产品工程已合入，画像、首页、计划、饮食、总结和历史流程可用；模拟训练闭环已在小米 15 Pro 真机验证；
- C 端 Android 原型位于 `native/android-training/`，支持 MediaPipe 姿态识别、深蹲/俯卧撑计数纠错以及完整训练会话生命周期；
- 原生会话支持暂停、继续、完成和取消，实际训练时长扣除暂停与后台时间；
- Flutter MethodChannel 与原生训练页已按冻结的 v1 协议接入，App 默认使用真实训练入口；
- Agent HTTP App Coach v1 已接入：计划、饮食和训练后总结分别请求，服务不可用时各自回退到本地模板；原生训练字段仍保持 v1 冻结语义；
- APP 已增加“教练”入口，支持 Agent 聊天、画像同步、聊天记忆查看与删除；消息可携带当前计划和最近真实训练事实；
- 已保留 Google MediaPipe 示例的 Apache 2.0 许可证和来源说明；
- iOS 因当前缺少 macOS/Xcode 硬件条件，不在本阶段范围内。

## 本次解决的问题

本分支重点解决 APP 与 Agent 在数据字段、隐私边界和失败处理上的分歧：

- 统一使用 HTTP App Coach v1。计划、饮食、本周回顾和训练后总结使用同一套字段、时间格式、错误码和开发鉴权；APP 不再上传完整用户画像中的本地不适字段。
- 训练结果先由 APP 本地保存，Agent 总结作为独立附加记录按 `installation_id + session_id` 幂等保存。Agent 不可用不会丢失原始训练，也不会把模板结果伪装成模型结果。
- 新增 `App Privacy Flow v1`。Video LLM、骨骼/URDF 适配器和复杂状态聚合器只提交语义 token、归一化统计和轨迹 token；摄像头视频、图片、像素、逐帧关键点和原始 URDF 不进入云端请求。
- APP 通过 `AgentCoachRepository.submitPrivacyFlow` 调用 `/api/app/v1/privacy/flow`，返回 token-only 回执、受限分析和透明红色本地轨迹叠加参数。观测受限时不会被显示为动作正确。
- 默认本地模式，用户必须在“Agent 连接”页面明确授权训练数据传输；正式服务要求 HTTPS，远程调试要求开发凭据。

协议文档：[APP Privacy Flow v1](docs/contracts/app_privacy_flow_v1.md)、[Agent 联调说明](docs/AGENT_INTEGRATION.md)。当前 `edge_catalog_v1` 只是可运行参考 token 适配器；TeleAI/智传网正式 SDK 接入时只能替换适配器，不能放开原始媒体字段限制。

最近验证：`flutter analyze` 无问题，Flutter 测试 `45 passed`（2 个 live case 默认跳过），计划/聊天/记忆真实客户端与本地 Agent live contract 已通过，Android Debug APK 构建成功。

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

`squat` 与 `push_up` 共用同一冻结接口；当前 D 的计划入口先使用 `squat`，后续增加俯卧撑产品入口时无需修改桥协议。

## D 端 Flutter 工程运行

```powershell
flutter pub get
flutter analyze        # 当前：No issues found
flutter test           # 当前：45 passed，2 个 live case 默认跳过
flutter devices
flutter run -d <设备ID>
```

Agent 联调默认请求 `http://127.0.0.1:8000/api/app/v1/`。模拟器或 USB 真机先执行 `adb reverse tcp:8000 tcp:8000`；也可使用 `--dart-define=AGENT_BASE_URL=...` 覆盖地址。完整边界见 `docs/AGENT_INTEGRATION.md`。

首页右上角“Agent 连接”可以设置地址、检测兼容性、授权训练数据传输和清除总结。默认本地模式，不静默上传。训练结束先保存原始记录，再后台生成总结；失败可重试，记录页支持本周回顾。服务端 `coach/config.json` 未填写模型密钥时明确使用模板，不伪报模型生成。

本机已配置 Flutter/Android SDK：运行 `. .\scripts\env.ps1` 加载工具，`scripts/build_debug.ps1` 自动检查、测试并构建 APK。中文工程路径使用英文构建副本，原目录保持不变。

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
