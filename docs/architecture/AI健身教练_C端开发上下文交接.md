# AI健身教练：系统架构与 C 端开发上下文交接

> 更新时间：2026-10-01  
> 用途：切换对话或开发上下文时，先阅读本文，避免重新讨论已经确定的架构或误用早期方案。  
> 当前负责人视角：App 端角色 C——App 运行基础与实时训练。

## 1. 一句话结论

本项目是一款“原始训练视频默认不出端”的 AI 健身教练：手机端通过 MediaPipe 和确定性动作算法实时完成姿态估计、计数与基础纠错，只把结构化运动事件发送给云端 Personal Agent；Agent负责训练组织、解释、长期记忆、总结和计划调整，不直接看视频重新判断关节角度。

当前 MVP 聚焦两个力量动作：

- 深蹲；
- 俯卧撑。

当前已经有一个可在 Android 真机运行的端侧原型，但它还不是完整产品 App，也尚未接入真实云端接口。

---

## 2. 已经确定的关键决策

### 2.1 端侧算法与 Agent 的边界

端侧算法回答“用户这一帧/这一组动作发生了什么”：

- 人体是否完整可见；
- 当前动作和阶段；
- 次数；
- 关键角度；
- 是否触发已登记的错误规则；
- 纠错反馈码及证据；
- 检测置信度和不可观测状态。

云端 Personal Agent 回答“如何组织、解释和继续训练”：

- 安排动作、组数和休息；
- 将结构化错误事件转为自然语言解释；
- 汇总一次训练；
- 读取历史记录和用户画像；
- 调整下一次计划；
- 提供非医疗级的基础饮食与激励建议。

Agent不能覆盖端侧算法结论，不能把 `not_observable` 解释为动作正确，也不能根据少量坐标自由发挥新的姿态诊断。

### 2.2 隐私边界

- 原始摄像头画面和训练视频默认不上传；
- 实时链路不上传人脸、背景、衣着或可重建完整画面的视觉 Token；
- 云端主要接收次数、阶段、角度、错误码、置信度和训练摘要；
- 匿名骨架窗口属于可选的更高语义级别，MVP 可以不实现；
- SAM3DBody 体型标定若以后实现，必须是独立、低频、显式授权流程，不能混入实时训练上传。

### 2.3 已放弃或暂缓的技术路线

以下内容可能出现在早期《分工讨论.md》中，但不属于当前 MVP 主链路：

- Video LLM 逐帧做姿态纠错；
- TeleAI/智传网先把视频编码为 Token，再由云端重建或理解；
- 把人体转换为 URDF；
- 多个彼此独立的大模型 Agent；
- 手机端逐帧运行 SAM3DBody-cpp；
- 为了“技术创新”而上传可恢复原画面的特征；
- 任意运动的开放识别；
- 医疗诊断或医疗级饮食建议。

Video LLM 对摔倒、复杂场景等特殊事件可能有价值，但与“原视频不上传”存在冲突，暂不进入实时核心链路。摔倒等安全事件应优先尝试端侧专用检测。

### 2.4 多动作不是共用同一套判定阈值

不同动作只共享分析框架，不共享全部判断逻辑：

- 共用：关键点质量门控、平滑、阶段状态机、事件聚合、反馈接口、端云协议；
- 动作专属：需要的关节、阶段阈值、错误规则、机位要求和反馈文案。

因此深蹲和俯卧撑分别有自己的动作规范，但都由同一个端侧分析引擎执行。

---

## 3. 当前总体架构

```text
手机摄像头
    ↓（原始帧只在端侧）
MediaPipe Pose Landmarker
    ↓ 33 个关键点 + visibility/presence
画面质量与可靠单侧选择
    ↓
动作专属规则与状态机
    ├─→ 屏幕骨架、计数、阶段、即时短反馈
    ├─→ 本地训练会话状态
    └─→ 结构化运动事件
               ↓ HTTPS / WSS（待接入）
云端业务与存储
    ↓
单一 Personal Agent + 明确工具接口
    ├─→ 教练语言与语音组织
    ├─→ 组间总结
    ├─→ 训练结果
    └─→ 下一次计划调整
```

系统包含两个不同时间尺度的闭环：

1. 端侧实时闭环：以几十毫秒级运行，负责检测、计数、纠错和短提示；
2. 云端教练闭环：以组间、训练后或下一次训练为单位，负责解释、记忆和规划。

网络断开时，端侧计数和本地反馈必须继续工作；Agent对话、历史同步和计划更新可以降级或延后。

---

## 4. 团队模块边界

### A：端侧运动算法

- MediaPipe 接入和关键点稳定；
- 动作确认或有限分类；
- 阶段、计数和动作错误规则；
- 视角、遮挡、置信度和不可观测状态；
- 纠正方向和反馈码；
- L0/L1/L2 运动语义输出。

当前 Android 原型中，A 的部分逻辑暂时由 C 端代码一起实现，用于先打通链路。后续若 A 提供独立算法模块，应通过稳定接口替换，而不是让 D 端页面直接读取 MediaPipe 对象。

### B：Personal Agent 与业务服务

- Agent 工具调用和对话；
- 阶段训练计划模板；
- 训练总结、历史和下一次计划调整；
- 基础饮食模板；
- 将结构化运动事实转成自然语言。

### C：App 运行基础与实时训练（本人负责）

- Android/App 工程和依赖；
- 摄像头权限、CameraX 与生命周期；
- 端侧算法模块接入；
- 实时训练页面；
- 本地训练状态、计数和即时反馈；
- 结构化事件适配与网络接入；
- 本地短语音、异常处理、打包和性能测试；
- 对外提供稳定的训练状态接口，供 D 端产品页面消费。

### D：产品功能与体验

- 首页、用户画像和训练计划页面；
- 历史、总结、饮食、激励和教练形象；
- 隐私授权和记录删除入口；
- 最终视觉风格与非实时业务交互。

### E：统筹、Schema 与测试

- 冻结范围和字段；
- 维护共享枚举、协议版本和动作规范版本；
- 建立测试样本、验收指标和联调流程；
- 处理不同模块间的职责冲突。

---

## 5. C 与 D 的推荐协作方式

不要让 C、D 两人同时修改摄像头 Fragment 或动作状态机。推荐模块边界如下：

```text
C 端实时训练模块
    输出 TrainingUiState / TrainingEvent / SessionCommand
                         ↓
D 端产品页面与导航
    只消费状态、发出用户操作，不接触摄像头帧和 MediaPipe 对象
```

C 应向 D 提供至少以下稳定状态：

- 当前动作；
- 当前阶段；
- 次数和组数；
- 具名角度；
- 可观测性和置信度；
- 本地反馈码与显示文本；
- 会话连接状态；
- Agent消息与训练命令；
- 开始、暂停、结束、切换动作等操作入口。

合码原则：

- C 维护 `camera/pose/training/network` 等运行模块；
- D 维护首页、计划、历史、用户画像等产品页面；
- 共享数据结构放在单独目录并由 E 冻结版本；
- D 不复制 C 的计数逻辑，C 不在算法层硬编码完整产品导航；
- 最终若改为 Flutter，C 提供 Platform Channel 或原生插件，D 通过 Dart 状态接口消费结果。

---

## 6. 当前 Android 原型位置

项目目录：

```text
D:\2026autumn\computer_application_competition\app\mediapipe-samples\examples\pose_landmarker\android
```

关键文件：

```text
app/src/main/java/com/google/mediapipe/examples/poselandmarker/
├── fragment/CameraFragment.kt       摄像头、MediaPipe与训练UI连接层
├── OverlayView.kt                   骨架绘制与低置信度过滤
└── training/ExerciseAnalyzer.kt     动作角度、状态机、反馈与事件

app/src/main/res/layout/
├── activity_main.xml                顶部导航和主内容布局
└── fragment_camera.xml              实时训练 HUD

app/src/test/.../ExerciseAnalyzerTest.kt
tools/ExerciseAnalyzerSmokeCheck.kt
verify_algorithm.ps1
build_local.ps1
FITNESS_COACH_PROTOTYPE.md
```

最新 APK：

```text
app/build/outputs/apk/debug/app-debug.apk
```

2026-10-01 最后构建信息：

- 大小：62,685,833 字节；
- SHA-256：`E022BB3C3AEB1F2DB4F58B5D3A90494421F4A350654119D4B6332C56B3C4633D`；
- 包名：`com.google.mediapipe.examples.poselandmarker`；
- minSdk 24，targetSdk/compileSdk 35；
- 已使用 `adb install -r` 成功覆盖安装到当时连接的 Android 真机。

---

## 7. 原型已经实现的功能

- CameraX 后置/前置摄像头实时预览；
- MediaPipe Pose Landmarker Lite 端侧推理；
- 33 点骨架覆盖；
- 根据 `visibility/presence` 隐藏低置信度点和连线；
- 深蹲与俯卧撑切换；
- 次数、阶段和具名角度显示；
- 重置和摄像头翻转；
- 原始视频不上传；
- `motion.rep_completed` 与 `motion.form_event` JSON 日志；
- 错误开始/结束事件，避免按帧重复输出；
- 断网不影响本地算法路径。

最近一次修复包括：

1. 修复训练按钮被 Camera/Gallery 导航栏覆盖；
2. 将深蹲“躯干角”改成肩—髋向量相对竖直方向的真实前倾角；
3. 按输入画面宽高修正归一化坐标造成的角度畸变；
4. 不再平均被遮挡的左右两侧，而是选择完整且置信度较高的一侧；
5. 连续 5 帧才确认阶段；
6. 必须先稳定处于起始位，再经过底部返回起始位才计数；
7. 连续丢失关键点后取消当前未完成动作；
8. 将“主角度/辅助角度”改成“膝角/躯干前倾”或“肘角/身体直线角”；
9. 将阶段显示改成“下蹲中、底部、起身中、站立”等更可读文案；
10. 压缩训练 HUD，减少遮挡人体。

---

## 8. 当前动作规则

这些阈值只是工程原型值，尚未经过数据集或运动医学验证。

### 深蹲

- 膝角不大于 `105°`：底部；
- 膝角不小于 `155°`：站立；
- 躯干相对竖直方向倾角大于约 `45°`：提示躯干过度前倾；
- 只使用可见度较高的一侧肩、髋、膝、踝；
- 必须先站立，再到底部并返回站立才计数。

### 俯卧撑

- 肘角不大于 `95°`：底部；
- 肘角不小于 `150°`：撑起；
- 肩—髋—踝角小于约 `155°`：提示身体没有保持直线；
- 只使用可见度较高的一侧肩、肘、腕、髋、踝；
- 必须先处于起始支撑位，再到底部并返回撑起位才计数。

共同参数：

- 关键点最低置信度：`0.55`；
- 阶段稳定帧数：`5`；
- 底部到起始位最短时间：`250 ms`；
- 角度使用指数平滑；
- 关键点连续丢失 5 帧后重置当前动作周期。

---

## 9. 构建与测试现状

本地工具位置：

```text
Android SDK / ADB：E:\Android\sdk
Android Studio/JBR：E:\Android\Studio\Android_studio
完整 Gradle 8.9：工作区 app\.tools\gradle-8.9-complete
Gradle依赖缓存：工作区 app\.gradle-user-home
```

算法冒烟测试：

```powershell
cd D:\2026autumn\computer_application_competition\app\mediapipe-samples\examples\pose_landmarker\android
powershell -ExecutionPolicy Bypass -File .\verify_algorithm.ps1
```

预期输出：

```text
ExerciseAnalyzer smoke checks passed
```

APK 常规构建：

```powershell
powershell -ExecutionPolicy Bypass -File .\build_local.ps1
```

安装：

```powershell
& 'E:\Android\sdk\platform-tools\adb.exe' install -r '.\app\build\outputs\apk\debug\app-debug.apk'
```

查看结构化事件：

```powershell
& 'E:\Android\sdk\platform-tools\adb.exe' logcat -s FitnessCoachEvent:I
```

最后验证结果：

- Kotlin/Android 代码和 APK 编译成功；
- JUnit 纯算法测试 `8/8` 通过；
- 离线冒烟测试通过；
- APK 覆盖安装成功；
- 端侧推理曾在真机观察到约 `37 ms/帧`，证明当前设备上端侧运行可行；
- 最近修复后的最终真机界面尚缺一次肉眼截图验收：当时手机进入 Doze 息屏状态，系统禁止 ADB 注入唤醒按键；
- Codex 沙箱中 Gradle 的测试 worker 可能因本机 loopback 限制失败，这不是代码编译失败。可以使用 `verify_algorithm.ps1`，或直接运行已经编译的 JUnit 类；普通用户终端通常不受该沙箱限制。

---

## 10. 前后端协议现状

协议文档：`AI健身教练_前后端通信协议_v0.1.md`。

协作层面的真实状态需要特别注意：

- 融合架构 v2 是目前最清晰、最一致的技术建议，但 Agent 组此前仍倾向沿用原来的产品/Agent 架构；
- 双方已经达成的最低共识是“视觉算法在前端运行、原始视频不上云”；
- 协议 v0.1 是据此拟定的联调草案，尚未得到 Agent 组对全部字段的正式确认；
- 因此不能把文档中的 URL、命令或消息字段当成已经上线的后端能力；
- C 端应先按协议抽象接口和假数据联调，避免在 Agent 组回复前绑定具体实现。

建议组合：

- HTTP：登录、会话创建、历史、计划、记录删除；
- WebSocket：训练中的事件、Agent消息和训练控制；
- 正式演示使用 HTTPS/WSS；
- App 内不能保存大模型 API Key。

前端 MVP 必须发送：

```text
client.session_state
motion.exercise_confirmed
motion.rep_completed
motion.form_event
motion.set_completed
client.user_report
client.session_summary
```

后端 MVP 必须发送：

```text
server.ack
server.error
agent.exercise_route
agent.coach_message
agent.training_command
agent.session_result
```

当前原型只把部分事件写入 Logcat：

- `motion.rep_completed`；
- `motion.form_event`。

当前 `session_id` 固定为 `local-prototype`，还没有真实会话层、WebSocket、ACK、断线重连、组次状态或摘要上传。

正式联调前仍需 Agent 组/E 角色冻结：

- 服务器地址与鉴权；
- `exercise_id`、`phase`、`error_code`、`feedback_code`；
- 严重度与置信度含义；
- `training_command` 白名单；
- ACK 超时、重试、去重和断线重连；
- 默认隐私等级、保存时间和删除接口；
- 动作规范版本号。

---

## 11. 目前没有完成的内容

### C 端直接待办

- 对最新修复版做一次真机界面验收；
- 分别测试深蹲、俯卧撑按钮、阶段和计数；
- 建立最小训练会话状态机：准备、热身、训练组、休息、结束；
- 增加组数、组内次数、计时和暂停；
- 把 `session_id`、动作规范版本和真实事件字段注入分析器外层；
- 先用假后端完成 WebSocket 双向联调；
- 实现 ACK、去重、断线缓存和重连；
- 接入 Agent 组提供的真实地址和鉴权；
- 为 D 提供稳定的 `TrainingUiState` 和操作接口；
- 增加本地短语音/音效，同时处理与 Agent 长语音的抢占；
- 补齐权限拒绝、摄像头中断、横竖屏和应用切后台等异常路径；
- 做性能、发热、电量和长时间稳定性测试。

### 算法/团队共同待办

- 采集或录制不同身高、速度、机位、光照和遮挡条件下的测试样本；
- 标注标准次数和常见错误；
- 计算计数准确率以及错误规则的 Precision、Recall、F1；
- 重新标定阈值和稳定帧数；
- 明确哪些错误不可从当前侧面单目画面可靠判断；
- 给不可观测状态明确反馈，不把“没检测出错”当作“正确”；
- 建立共享动作规范文件，而不是把所有阈值永久硬编码在 App 中。

### 产品与云端待办

- 用户画像、首页、计划、历史、饮食卡和激励；
- Agent训练总结；
- 用本次训练结果真实调整一次下一次计划；
- 训练记录查看和删除；
- 隐私授权、数据级别和保存策略页面。

---

## 12. 推荐的下一步执行顺序

1. 点亮手机，验收最新 UI：两个动作按钮、具名角度、布局无遮挡；
2. 每个动作先各做 5 次标准动作，记录真人次数与 App 次数；
3. 测试遮挡、离开画面、从底部入镜、快速抖动等边界情况；
4. 保存 Logcat 事件，核对 `rep_index`、阶段、角度和错误码；
5. 根据结果修正端侧规则，不急于增加新动作；
6. 实现 C 端训练会话状态机和 `TrainingUiState`；
7. 根据协议 v0.1 写假 WebSocket 服务或适配器，完成本地端到端联调；
8. 等 Agent 组冻结地址和字段后替换假后端；
9. 与 D 合并完整产品页面；
10. 最后再考虑统一虚拟人、SAM3DBody 标定、iOS 或原生鸿蒙适配。

当前最重要的不是继续叠加模型，而是把“端侧可靠识别 → 结构化事件 → Agent总结 → 下一次计划调整”这一条闭环真正跑通并量化验证。

---

## 13. 跨平台现状

### Android

已有 APK 和可运行原型，是当前唯一实际完成的移动端版本。

### iOS

目前没有 `.ipa`。需要 macOS、Xcode、iOS 工程和签名；Camera/MediaPipe/界面均需适配。Android APK 不能转换成 IPA。

### HarmonyOS

- HarmonyOS 4.x及以下/EMUI 可先尝试安装 APK；
- HarmonyOS 5及以上正式适配应使用 DevEco Studio、ArkTS/ArkUI、Camera Kit 和 MindSpore Lite/Native C++，输出 `.hap`；
- 卓易通兼容 APK 只能作为临时测试，不能作为比赛正式技术方案；
- 当前没有原生鸿蒙工程。

比赛阶段建议以 Android 为主，不要同时启动 iOS 和原生鸿蒙重写，除非赛事明确要求。

---

## 14. 文档优先级

新上下文应按以下顺序阅读：

1. `AI健身教练_C端开发上下文交接.md`：当前事实和下一步；
2. `AI健身教练_融合架构_v2.md`：当前整体架构与团队边界；
3. `AI健身教练_前后端通信协议_v0.1.md`：端云接口；
4. `AI健身教练_APP调试与使用指南.md`：真机测试方法；
5. `app/mediapipe-samples/examples/pose_landmarker/android/FITNESS_COACH_PROTOTYPE.md`：代码与构建说明；
6. `AI健身教练_建议技术架构.md`：架构论证和创新表述；
7. `产品想法.md`：产品功能来源；
8. `分工讨论.md`：仅作为历史会议记录，不代表现行技术方案。

如文档冲突，以本交接文档、融合架构 v2、协议 v0.1 和当前代码为准。

---

## 15. 给新上下文的简短提示词

```text
请先阅读工作区下的《AI健身教练_C端开发上下文交接.md》、
《AI健身教练_融合架构_v2.md》和《AI健身教练_前后端通信协议_v0.1.md》。
我负责角色 C：App运行基础与实时训练。
当前 Android MediaPipe 原型已经支持深蹲和俯卧撑，原视频不上云，
动作算法在端侧，Personal Agent只处理结构化事件、总结和计划。
不要恢复 Video LLM/TeleAI/URDF 主链路，也不要覆盖已有工作区修改。
先检查当前代码和真机状态，再从交接文档的“推荐下一步执行顺序”继续。
```

