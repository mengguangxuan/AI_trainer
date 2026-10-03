# 10 月 1 日移动端整合决策与验收单

适用范围：D 的 Flutter 产品原型与 C 的 Android 姿态识别原型。截止提交日按 **10 月 8 日**安排。本文是待团队确认的实施建议，不表示 C 的源码或 Agent 接口已经完成。

## 已核实的事实

- D 工程已经定义 `TrainingGateway.start(context, TrainingLaunchArgs)`，返回 `SessionResult?`；首页、计划、模拟训练、总结与历史在小米手机上走通。当前入口只安排模板深蹲，模拟训练并非真实识别。
- 本轮 C APK `01-app-debug.apk.1` 大小 62,685,833 字节，SHA-256 为 `e022bb3c3aeb1f2db4f58b5d3a90494421f4a350654119d4b6332c56b3c4633d`。包中有 `assets/pose_landmarker_lite.task`、MediaPipe Android 原生库及 Android CameraX 组件，没有 Flutter 资源。Manifest 字符串中出现 `com.google.mediapipe.examples.poselandmarker`、`CAMERA`、`INTERNET`。这证明它是一份独立的 Android 安装包，不能据此断定纠错逻辑、训练结果输出或后端连接已经实现。深蹲与俯卧撑、手动选择、真机能运行由 C/用户报告，尚未在本工作区复测其动作计数精度。
- 比赛说明扫描件第 17–18 页要求完整源代码、安装包及演示视频；Android/鸿蒙作品可提交安装包。跨平台工具按 Android 项目要求提交；没有要求同一作品同时支持 iOS。iOS 版本不在本周交付路径上。

## 选择的整合方向

**优先以 D 的 Flutter 工程作为唯一 App 外壳，把 C 的 Android 原生训练页面及识别代码接入其 `android/` 宿主；D 的 `TrainingGateway` 调用原生页面，页面结束时返回真实 `SessionResult`。** Native Activity + Flutter `MethodChannel` 是可行路径，具体 Gradle/Manifest/Activity 迁移方式由 C 看到双方源码后决定。若 C 现有 Android 项目更适合当宿主，可反向把 Flutter D 做成 add-to-app 模块，但要先做半天可运行验证，不在两个方向之间反复改造。

APK 是已经编译好的安装包，不是可复制进 Flutter 的源码模块。不要把两份 APK 合并压缩、反编译重构，或把要求用户安装两个应用的跳转当成最终的一体化交付。需要 C 的可构建源工程、模型文件、资源、Gradle 依赖和明确的输入/输出接口。

Flutter 与 Android 已通过 `MethodChannel('ai_fitness/training_v1')` 的 `startTraining` 接通；`main.dart` 默认使用 `NativeTrainingGateway`。原生模块通过 `android/trainingbridge` 引用 `native/android-training` 的同一份源码和模型，避免复制两套算法实现。`MockTrainingGateway` 仅保留给独立界面测试和演示回退，不再是产品默认入口。

## 先冻结的最小接口（沿用 D 工程 v1）

### D → C：一次只启动一个动作

```json
{
  "schema_version": 1,
  "plan_item_id": "template_squat_01",
  "training_mode": "planned",
  "exercises": [{"exercise_id": "squat", "target_sets": 1, "target_reps": 6, "rest_seconds": 45}],
  "coach_name": "AI 私教"
}
```

`exercise_id` 首批只约定 `squat` 和 `push_up`。每次调用锁定一个动作，不允许在训练页切换。D 当前模板仅有 `squat`，俯卧撑入口须在真实桥接跑通后增加，不能单靠 C 原型可选就宣称 D 支持俯卧撑。

### C → D：离开训练页必须给出确定结果

```json
{
  "schema_version": 1,
  "session_id": "unique-session-id",
  "status": "completed",
  "finished_at": "2026-10-01T20:00:00+08:00",
  "duration_seconds": 35,
  "exercises": [{
    "exercise_id": "squat",
    "completed_sets": 1,
    "completed_reps": 6,
    "quality_trend": null,
    "main_error_code": null
  }],
  "agent_summary": null,
  "next_plan_changed": false,
  "source": "real"
}
```

上面**只是一份协议样例，数字是假设值，不是对 C APK 的测量**。`status` 限 `completed / cancelled / interrupted`；取消或异常不能增加完成次数、连续天数。`source=real` 只用于真实识别产生的训练结果，模拟结果继续标 `mock`。没有算法支持的质量趋势、错误码、Agent 总结保持 `null`。`next_plan_changed` 只有 Agent 已经实际生成并保存新计划时才能设为 `true`；首轮桥接固定 `false`。未知错误码由 D 保守显示，不推断健康结论。C 与 D 共同确定系统返回键和相机权限拒绝时的状态语义。

## 分工与每天交付门槛

| 时间 | C | D | Agent 组三位同学/统筹 | 通过门槛 |
|---|---|---|---|---|
| 10/1 | 提供 Android Studio **源码**、模型、依赖清单、入口 Activity、实际能输出的计数/错误码 | 提供 Flutter 源码、`TrainingGateway` 和 JSON 草案；留存现有可运行版本 | 确认只做 Android 单包、深蹲和俯卧撑优先级；明确谁负责协议字段 | 双方能在各自机器上构建原工程，并签下最小接口 |
| 10/2 | 集成 Activity/原生桥，先传入深蹲并返回真实 `SessionResult` | 接好 Gateway、总结/历史的真实数据来源；模拟版可切换 | 提供计划/饮食/训练后更新的**一套真实请求响应样例**和错误格式 | 同一 APK 内，从 D 首页进入 C 训练并返回 D 总结 |
| 10/3 | 俯卧撑进入和结束、取消/权限拒绝路径 | D 增加相应计划或自由训练入口及结果展示；手机尺寸下首屏视觉修订 | 确认后端地址、鉴权部署和离线回退 | 深蹲与俯卧撑均可真机完成；取消不计数 |
| 10/4–5 | 计数/纠错稳定性、相机生命周期、无网行为 | 首页/计划/总结/历史视觉统一；接入 Agent 已冻结的计划/饮食接口 | Agent 连通、超时/错误处理，真实计划更新 | 一条完整链路 `画像→计划→识别→总结→历史→下一计划`，每段来源可解释 |
| 10/6–7 | 构建候选 APK、修复崩溃 | 三张核心截图、设计文档中的 D 模块说明 | 共同录制不超过 5 分钟演示视频，核对源代码和引用 | 干净设备安装单 APK、无网/拒权/取消回归、提交材料齐全 |
| 10/8 | 与统筹提交最终版本 | 与统筹提交最终版本 | 与统筹提交最终版本 | 提交平台实际收到完整包和材料 |

日期是内部安排，若队友当前进度不同，以**通过门槛**为准。当 Agent 真实接口迟到时保留明确标注的模板计划/饮食，不把模拟文案伪装成 AI 实时反馈。训练模块优先保证真实感知和数据闭环。

## 联调日每次同步四样东西

1. C 与 D：**同一份**构建的版本/commit、当前入口动作 ID、一次完成和一次取消的真实 JSON、手机上看到的故障或录屏。谁动 `android/`、`pubspec.yaml`、路由和协议先在群里说明。
2. Agent → D：计划/饮食接口的 URL、请求/响应、超时和失败样例；D → Agent：画像与 `SessionResult` 的实际字段及数据来源。
3. C ↔ Agent：端侧究竟产生什么事件、纠错码列表、是否上传关键点/视频，以及训练中消息格式。不能仅给接口名称。
4. 全队：次日唯一关键验收点、阻塞负责人、提交版 APK 与源码所在位置。每天下午留一个可安装构建，不等到 10/7 才合并。

## 单包验收清单

- [ ] 仅安装一个 APK；首页、画像、计划、摄像头训练、总结和历史都在同一包内。
- [ ] `squat` 与 `push_up` 各跑一次，动作选择、计数和最终结果一致；以实测能力展示，不能承诺未实现的自动识别动作种类。
- [ ] 开始→返回/取消→重新进入；拒绝相机权限→可恢复；训练中关网→明确状态；切到后台→返回，不崩溃或误计完成。
- [ ] 真训练 `source=real`，模拟/模板有可见标注；完成才计入历史统计；应用重启后结果仍在。
- [ ] 最终 APK 在小米真机安装；`flutter analyze` / `flutter test` 和 Android 构建通过。发布包与调试包差异由 C 管理。
- [ ] 比赛资料含完整原始工程、第三方 MediaPipe/示例代码出处与团队原创改动说明，说明程序设计语言、工具及平台；演示视频格式/大小按比赛说明复核。

## 暂不投入 iOS

Android APK 无法在 iPhone 上运行。Flutter 的产品 UI 可迁移，但 C 这份 Android 原生 MediaPipe/CameraX 代码没有自动生成的 iOS 实现；做 iOS 要另做相机与模型接入，并需 macOS/Xcode 打包。提交周期内按比赛允许的 Android 安装包完成作品，文档注明当前支持平台。赛后再评估 iOS。
