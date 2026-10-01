# C 端对 D 端移动端合并问题的回复

> 回复日期：2026-10-01  
> 依据：当前 Android 源码、《AI健身教练_C端开发上下文交接.md》和《AI健身教练_前后端通信协议_v0.1.md》  
> 目标：先把 Flutter 首页 → 原生实时训练 → Flutter 总结页打通，第一轮只做单动作训练。

## 结论

同意由 C 负责 Android 原生训练模块迁移和桥接，D 负责 Flutter Gateway、计划入口、总结、历史和产品视觉。第一优先级是补齐 `TrainingLaunchArgs / SessionResult v1` 和训练结束回传，然后先接通深蹲，再复用同一接口接俯卧撑。

当前 APK 对应的完整 Android Studio 工程源码位于：

```text
app/mediapipe-samples/examples/pose_landmarker/android
```

工程包含 Gradle 配置、Manifest、CameraX/MediaPipe 源码、动作分析器、布局资源、测试和 `pose_landmarker_lite.task`。构建缓存、APK、本机 SDK 路径和密钥不应提交。建议通过团队 Git 仓库交付和合并源码，不再通过压缩包来回覆盖。

## 1. 训练入口、包名和动作预选

当前入口如下：

```text
Activity：com.google.mediapipe.examples.poselandmarker.MainActivity
实时训练 Fragment：com.google.mediapipe.examples.poselandmarker.fragment.CameraFragment
namespace/applicationId：com.google.mediapipe.examples.poselandmarker
```

启动后先进入 `PermissionsFragment`。相机权限通过后导航到 `CameraFragment`。

当前不能从外部传入动作。`ExerciseAnalyzer` 默认选择 `squat`，用户只能在相机页点击按钮切换到 `push_up`。合并时会增加外部参数，并将允许值限制为：

```text
squat
push_up
```

建议在一个 APK 中保留 Flutter `MainActivity` 作为产品入口，把当前原生入口改成内部使用的 `TrainingActivity`。Flutter Gateway 通过 MethodChannel 启动 `TrainingActivity`，传入 `TrainingLaunchArgs`；训练结束后原生页向 Flutter 返回 `SessionResult`。第一版使用独立全屏原生 Activity，比立即把 CameraX 嵌入 Flutter PlatformView 更容易稳定交付。

正式合并时还应把 `com.google.mediapipe.examples.poselandmarker` 改为团队自己的命名空间，避免把 Google 示例包名作为参赛产品包名。

## 2. 停止训练与结果回传

当前还不能导出完整训练结果。

已经真实存在于运行时的数据：

- 当前实际动作 ID；
- 已计次数；
- 当前阶段；
- 关键角度；
- 当前纠错码；
- `motion.rep_completed` 和 `motion.form_event` 事件。

尚未实现的数据和行为：

- 训练开始、结束时间与持续时间；
- 明确的“完成训练”和“取消训练”操作；
- 完成/取消状态；
- 原生页向 Flutter 返回结果；
- 训练会话 ID、目标次数和动作规范版本的外层注入；
- 组次以及最终错误统计。

当前事件只写入 Logcat，`session_id` 固定为 `local-prototype`。序列化器当前输出的结构如下；数值为格式示例，不是保存在仓库中的真机日志：

```json
{
  "protocol_version": "0.1",
  "message_id": "local_1790841600000_1",
  "type": "motion.rep_completed",
  "session_id": "local-prototype",
  "sequence": 1,
  "client_time_ms": 1790841600000,
  "requires_ack": false,
  "payload": {
    "exercise_id": "squat",
    "rep_index": 1,
    "phase": "up",
    "event_action": null,
    "error_code": null,
    "metrics": {
      "knee_angle_deg": 164.2,
      "torso_lean_deg": 17.8
    },
    "feedback_code": "OK"
  }
}
```

同意优先补结果回传。若 D 的 `MOBILE_INTEGRATION_PLAN.md` 尚未同步到当前工作区，可先按下面的最小契约实现，等该文档进入 Git 后再做字段逐项映射。

建议的启动参数：

```json
{
  "schema_version": "1",
  "session_id": "session_001",
  "exercise_id": "squat",
  "target_reps": 10
}
```

建议的完成结果：

```json
{
  "schema_version": "1",
  "session_id": "session_001",
  "exercise_id": "squat",
  "actual_reps": 8,
  "status": "completed",
  "started_at_ms": 1790841600000,
  "ended_at_ms": 1790841642315,
  "duration_ms": 42315,
  "algorithm_version": "motion_rules_0.1",
  "exercise_spec_version": "squat_0.1"
}
```

建议的取消结果：

```json
{
  "schema_version": "1",
  "session_id": "session_001",
  "exercise_id": "squat",
  "actual_reps": 3,
  "status": "cancelled",
  "started_at_ms": 1790841600000,
  "ended_at_ms": 1790841616050,
  "duration_ms": 16050,
  "algorithm_version": "motion_rules_0.1",
  "exercise_spec_version": "squat_0.1"
}
```

取消结果可以携带真实次数供本地诊断，但 D 端不得把它计为已完成训练。是否达到 `target_reps` 与用户点击“完成”应分别记录；第一版 `status` 只允许 `completed` 和 `cancelled`，异常退出后续可增加 `aborted`。

## 3. 已实现的纠错项与 Agent 状态

当前真正实现的纠错项如下：

| 动作 | `error_code` | `feedback_code` | 当前计算依据 |
|---|---|---|---|
| 通用 | `camera.landmarks_missing` | `ADJUST_CAMERA_POSITION` | 当前动作所需的一整侧关键点不能全部达到 `visibility/presence >= 0.55`；连续丢失 5 帧后取消未完成动作周期 |
| 深蹲 | `squat.depth_shallow` | `GO_DEEPER` | 已进入有效动作周期，但回升时膝角仍小于 `135°` 且没有稳定到达底部 |
| 深蹲 | `squat.torso_lean` | `KEEP_CHEST_UP` | 肩—髋向量相对画面竖直方向的倾角大于 `45°` |
| 俯卧撑 | `push_up.depth_shallow` | `GO_LOWER` | 已进入有效动作周期，但撑起时肘角仍小于 `125°` 且没有稳定到达底部 |
| 俯卧撑 | `push_up.body_line_bent` | `KEEP_BODY_STRAIGHT` | 肩—髋—踝夹角小于 `155°` |

相关计数规则：

- 深蹲膝角不大于 `105°` 才进入底部，膝角不小于 `155°` 才回到站立位；
- 俯卧撑肘角不大于 `95°` 才进入底部，肘角不小于 `150°` 才回到撑起位；
- 阶段需要连续 5 帧确认；
- 必须先稳定处于起始位，再到底部并返回起始位才计数；
- 底部到起始位至少间隔 250 ms；
- 角度采用指数平滑，并按输入画面的实际宽高修正归一化坐标畸变；
- 左右侧不做盲目平均，只选择所需关键点完整且置信度更高的一侧。

当前没有连接 Agent，也没有 WebSocket、ACK、重连或云端总结。纠错完全由端侧确定性算法产生，事件目前只写 Logcat。`severity`、事件级 `confidence` 和 Agent 消息均未实现，可以在 v1 中为空或省略，不能填造假的默认值。

这些阈值属于工程原型值，尚未通过标注数据集或运动医学验证。

## 4. 构建版本、依赖、来源和改动范围

当前构建环境：

```text
Android Gradle Plugin：8.7.3
Gradle：8.9
Kotlin Android Plugin：1.8.0
JDK：build_local.ps1 优先使用 JDK 21，否则使用 Android Studio JBR
Java/Kotlin bytecode target：1.8
compileSdk：35
targetSdk：35
minSdk：24
```

主要依赖：

```text
androidx.core:core-ktx:1.8.0
androidx.appcompat:appcompat:1.5.1
com.google.android.material:material:1.7.0
androidx.constraintlayout:constraintlayout:2.1.4
androidx.fragment:fragment-ktx:1.5.4
androidx.navigation:navigation-*:2.5.3
androidx.camera:camera-*:1.4.2
androidx.window:window:1.1.0-alpha03
com.google.mediapipe:tasks-vision:1.0.0
junit:junit:4.13.2
```

Windows 当前可成功执行的命令：

```powershell
cd app\mediapipe-samples\examples\pose_landmarker\android
powershell -ExecutionPolicy Bypass -File .\build_local.ps1
```

脚本实际执行：

```text
gradle --no-daemon testDebugUnitTest assembleDebug
```

生成位置：

```text
app/build/outputs/apk/debug/app-debug.apk
```

最近已验证 APK 的 SHA-256：

```text
E022BB3C3AEB1F2DB4F58B5D3A90494421F4A350654119D4B6332C56B3C4633D
```

上游来源是 Google 官方 `google-ai-edge/mediapipe-samples` 仓库中的 Pose Landmarker Android 示例：

```text
https://github.com/google-ai-edge/mediapipe-samples/tree/main/examples/pose_landmarker/android
```

上游示例仓库使用 Apache License 2.0，当前仓库根目录保留了 `LICENSE`，原文件中的 TensorFlow Authors 版权头也必须保留。`pose_landmarker_lite.task` 来自官方 Pose Landmarker 示例资源，不能表述为团队自行训练的模型。正式提交时还应整理第三方依赖清单和 NOTICE/开源说明。

团队在上游示例基础上的主要改动是：

- 新增 `training/ExerciseAnalyzer.kt`，实现深蹲和俯卧撑的角度、阶段、计数、纠错和事件生成；
- 新增纯算法 JUnit 测试与离线冒烟测试；
- 将动作分析接入 `CameraFragment`；
- 修改 `OverlayView`，按置信度过滤关键点和连线；
- 修改实时训练 HUD、动作切换、计数、阶段、角度和反馈显示；
- 更新 CameraX、Gradle、SDK 与离线模型构建配置；
- 新增本地构建、算法验证和项目交接文档。

CameraX、MediaPipe 推理封装、相册示例、权限页和基础导航主要源自官方示例；比赛材料中应明确区分“上游基础能力”和“团队新增的健身动作分析、隐私架构、协议及产品闭环”。

## 5. 权限、取消、返回、后台和断网行为

当前实际行为如下：

| 场景 | 当前行为 | 合并前需要补齐 |
|---|---|---|
| 相机权限拒绝 | Toast 提示拒绝，停留在权限页，不进入训练 | 增加原因说明、重新申请和前往系统设置入口，并向 Flutter 返回无法开始 |
| 训练取消 | 没有取消按钮和取消状态 | 增加取消确认，返回 `status=cancelled` |
| 按系统返回键 | `MainActivity.onBackPressed()` 直接 `finish()`，不返回训练结果 | 改为训练中弹出确认；确认退出后返回取消结果 |
| 应用进入后台 | `onPause()` 关闭 Pose Landmarker；回到前台后重新初始化 | 同时暂停会话计时/状态，防止后台时长和动作被误计；需要真机验证恢复 |
| Fragment/View 被销毁或进程被杀 | 当前会话数据不持久化，可能丢失 | v1 至少保存启动参数、次数、起止时间和状态，进程恢复策略另行定义 |
| 断网 | 不影响识别、计数和本地纠错，因为当前完全没有网络链路 | 接入后仍保持本地训练；事件缓存、ACK 和重连属于后续协议层工作 |

因此当前识别不需要网络，原始摄像头画面也不会上传。

## 6. `TrainingLaunchArgs / SessionResult v1` 对接意见

同意按 D 的 v1 接口对接，约束如下：

1. 每次只启动一个动作；第一版只接受 `squat` 和 `push_up`。
2. 动作必须由启动参数预选，进入相机页后默认不允许随意切换到另一个动作；调试构建可保留切换入口。
3. 完成时返回端侧真实计数和实际时长，不用目标次数冒充完成次数。
4. 取消时返回 `status=cancelled`，D 端不将本次训练计为完成。
5. 原始视频、图片和可还原画面的视觉特征不进入返回结果。
6. Flutter 只消费训练状态和结果，不接触 CameraX、MediaPipe 对象或逐帧关键点。
7. `MOBILE_INTEGRATION_PLAN.md` 当前不在本工作区。请 D 将它提交到团队 Git 仓库；收到后以该文件冻结最终字段名、空值规则和版本号。

建议桥接调用保持简单：

```text
Flutter TrainingGateway.startTraining(args)
    → MethodChannel
    → Android TrainingActivity
    → CameraFragment + ExerciseAnalyzer
    → SessionResult JSON
    → Flutter 总结页
```

第一轮验收条件：从 D 首页选择深蹲，原生训练页收到 `exercise_id=squat`，完成若干次后点击结束，Flutter 总结页显示原生返回的实际次数和时长；按返回键取消时不生成完成记录。俯卧撑使用同一通道和数据结构作为第二步接入。

## Git 协作建议

建议立即使用 Git 协作。现在已经需要同时修改 Flutter 入口、Android 原生模块和桥接契约，继续传压缩包很容易覆盖对方修改，也无法清楚证明比赛项目中各成员的贡献。

当前 `app/mediapipe-samples` 是 Google 官方仓库的克隆，`origin` 仍指向：

```text
https://github.com/google-ai-edge/mediapipe-samples
```

它不是团队集成仓库。建议新建一个团队私有仓库，以 D 的 Flutter 工程作为最终 App 主工程，只迁入需要的原生训练代码、模型和许可证，不把整个 MediaPipe 示例合集当作产品仓库。

推荐最小规则：

- `main` 始终保持可构建、可演示；
- C 使用 `feature/android-training-bridge`，D 使用 `feature/flutter-product-pages`；
- 每次通过小型 Pull Request 合并，桥接协议的改动由 C、D 双方检查；
- C 主要维护 `android/.../training`、CameraX/MediaPipe 和 MethodChannel 原生实现；
- D 主要维护 `lib/` 下的 Flutter 页面、Gateway、总结和历史；
- 共享 JSON Schema、枚举和版本放在 `docs/contracts/`，变更时两端一起更新；
- 提交模型文件和源码，保留上游许可证；不要提交 `build/`、`.gradle/`、APK、`local.properties`、密钥、签名文件和真实 Token；
- 当前模型约 5.6 MB，可直接纳入 Git；未来模型明显增大或出现多个版本时再启用 Git LFS；
- 每次合并前至少执行 Android 单元测试与 debug APK 构建，Flutter 侧执行分析和相应测试。

建议的近期提交顺序：

1. D 提交 Flutter 主工程和 `MOBILE_INTEGRATION_PLAN.md`；
2. C 迁入并整理原生训练模块、上游 LICENSE 和模型；
3. 双方冻结 `TrainingLaunchArgs / SessionResult v1`；
4. C 实现深蹲启动、结束与取消回传；
5. D 接入首页和总结页；
6. 真机验收后，以同一接口开放俯卧撑。
