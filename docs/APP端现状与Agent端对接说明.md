# App 端现状与 Agent 端对接说明

> 更新时间：2026-10-03
>
> App 分支：`feature/android-training-bridge`
>
> 基线提交：`017aee0`
>
> 面向对象：计划 Agent、饮食 Agent、训练总结/教练 Agent 及后端接口负责人

## 1. 当前结论

当前 App 已形成一个可构建的 Android 单包：Flutter 负责用户画像、首页、计划、饮食、训练总结和历史；Android 原生模块负责 CameraX、MediaPipe、动作计数和实时纠错。Flutter 与原生训练页已通过冻结的 Training Bridge v1 接通，App 默认进入真实训练页，不再默认使用模拟训练页。

Agent 服务尚未接入。当前计划和饮食来自本地模板，界面会明确标注“本地示例模板”；训练总结中的 Agent 总结、质量趋势和计划调整也尚未生成。

当前主流程为：

```text
填写/修改画像
    → 本地模板生成计划与饮食
    → 从首页或计划页开始训练
    → Android 相机与端侧算法完成计数
    → Flutter 接收 SessionResult
    → 保存本地记录并刷新计划/饮食
    → 展示总结、历史、完成次数和连续训练天数
```

## 2. 已实现的 App 功能

### 2.1 用户画像

App 支持首次填写和后续修改画像，并使用 `SharedPreferences` 保存在本机。当前字段如下：

| 字段 | 类型 | 当前可选值/含义 |
|---|---|---|
| `goal` | string | `建立运动习惯`、`提升力量`、`改善体能` |
| `experience` | string | `新手`、`有规律运动` |
| `days_per_week` | integer | `1`、`2`、`3`、`4` |
| `minutes_per_session` | integer | `10`、`15`、`20`、`30` |
| `has_equipment` | boolean | 是否有基础训练器械 |
| `has_current_discomfort` | boolean | 当前是否有身体不适 |
| `diet_preference` | string | `无特别偏好`、`素食`、`有过敏或特殊限制` |

当 `has_current_discomfort=true` 时，本地模板不会提供“开始训练”入口。该字段可能涉及健康隐私，当前只保存在本机；未经用户授权和团队确认，Agent 接口不得默认上传。

当前 JSON 形状：

```json
{
  "schema_version": 1,
  "goal": "建立运动习惯",
  "experience": "新手",
  "days_per_week": 2,
  "minutes_per_session": 15,
  "has_equipment": false,
  "has_current_discomfort": false,
  "diet_preference": "无特别偏好"
}
```

### 2.2 首页、计划和饮食

App 当前有四个底部入口：

- 首页：展示今日训练、本地饮食提示、已完成次数和连续训练天数；
- 计划：展示阶段、计划原因、动作、组数、次数和休息时间；
- 饮食：展示建议标题与正文，并显示内容来源；
- 记录：展示本地训练历史，可进入单次训练总结。

当前 `TemplateCoachRepository` 的行为：

- 新手深蹲目标为 1 组 × 6 次；
- 有规律运动用户的深蹲目标为 1 组 × 8 次；
- 组间休息字段为 45 秒，但 Training Bridge v1 只有一组，原生训练页不会执行自动组间休息；
- 已有完成记录时，本地模板继续安排同一动作；
- 当前有身体不适时返回无训练项目的暂停安排；
- 饮食内容只是保守的本地示例，不计算热量，也不提供疾病或过敏的个体化医疗建议。

所有计划和饮食对象都有 `source` 字段，当前使用 `template`；真实 Agent 内容应使用 `agent`。App 会在页面上显示来源，Agent 失败时不会把模板伪装成 Agent 输出。

### 2.3 Android 真实训练

App 默认使用 `NativeTrainingGateway`，通过以下 MethodChannel 打开原生训练页：

```text
channel: ai_fitness/training_v1
method: startTraining
```

原生训练能力包括：

- CameraX 相机预览；
- MediaPipe Pose Landmarker 姿态关键点识别；
- 深蹲 `squat` 和俯卧撑 `push_up` 的端侧动作分析；
- 实时次数统计和本地短反馈；
- 暂停、继续、完成、取消和系统返回确认；
- 相机权限拒绝、模型/相机初始化失败等异常状态；
- 使用单调时钟计算训练时长，扣除主动暂停和进入后台的时间；
- 完成、取消或中断后向 Flutter 返回结构化结果。

原生算法、桥协议和 Flutter `TrainingPlanItem` 均已支持显式传递 `squat/push_up`。当前本地模板只生成深蹲，所以现有用户界面仍只有深蹲入口；真实 Agent 接入后可以通过计划项的 `exercise_id` 选择深蹲或俯卧撑。

### 2.4 训练结果、总结和历史

原生桥当前返回冻结的 `SessionResult`：

```json
{
  "schema_version": 1,
  "session_id": "unique-session-id",
  "status": "completed",
  "finished_at": "2026-10-03T17:50:00+08:00",
  "duration_seconds": 35,
  "exercises": [
    {
      "exercise_id": "squat",
      "completed_sets": 1,
      "completed_reps": 6,
      "quality_trend": null,
      "main_error_code": null
    }
  ],
  "agent_summary": null,
  "next_plan_changed": false,
  "source": "real"
}
```

状态语义：

| `status` | 含义 | App 统计行为 |
|---|---|---|
| `completed` | 用户主动完成训练 | 计入完成次数和连续训练天数 |
| `cancelled` | 用户取消或确认系统返回 | 可保留为未完成记录，不计入完成统计 |
| `interrupted` | 权限、相机、模型或系统异常中断 | 可保留为未完成记录，不计入完成统计 |

本地记录使用 `session_id` 去重，最多保留最近 30 条。每次画像保存和训练结果落库后，`ProductController` 都会重新请求计划与饮食。

Training Bridge v1 对原生返回值有严格限制：

- `source` 固定为 `real`；
- `agent_summary` 固定为 `null`；
- `next_plan_changed` 固定为 `false`；
- `quality_trend` 和 `main_error_code` 固定为 `null`；
- 原生训练页退出必须返回 `completed/cancelled/interrupted`，不得返回 `null`。

这些限制只约束 Android 原生桥。未来 Agent 生成训练总结或更新计划时，应由 Flutter/服务层在收到真实 `SessionResult` 后另行调用 Agent，而不是让 Android 原生模块伪造 Agent 字段。

## 3. 已预留的 Agent 接入点

当前 App 已定义 `CoachRepository`：

```dart
abstract class CoachRepository {
  Future<TrainingPlan> fetchPlan(
    UserProfileSnapshot profile,
    List<SessionResult> history,
  );

  Future<NutritionAdvice> fetchNutrition(UserProfileSnapshot profile);
}
```

真实 Agent 接入的最小改动方式是：

1. 新建一个实现 `CoachRepository` 的网络 Repository；
2. 将请求/响应 JSON 映射为现有 Dart 对象；
3. 在 `main.dart` 中用真实 Repository 替换 `TemplateCoachRepository`；
4. 保留本地模板作为超时、断网或服务异常时的降级结果。

当前控制器会先请求计划，再请求饮食。任一请求抛出异常时，计划和饮食都会一起回退到本地模板，并将 `usingFallback` 设为 `true`。

### 3.1 App 当前可消费的计划对象

以下是 Dart 对象的当前形状，不代表已经冻结的 HTTP 协议：

```json
{
  "plan_id": "agent_plan_001",
  "stage_name": "适应期",
  "headline": "今天练习深蹲",
  "reason": "根据用户画像和最近训练记录生成的简短原因",
  "item": {
    "id": "agent_plan_item_001",
    "exercise_id": "squat",
    "title": "徒手深蹲",
    "target_sets": 1,
    "target_reps": 6,
    "rest_seconds": 45
  },
  "source": "agent"
}
```

当不应安排训练时，`item` 可以为 `null`，但必须提供可展示的 `stage_name`、`headline` 和 `reason`。

目前桥协议只支持一次一个动作、`target_sets=1`。Agent 即使支持多动作或多组，也应在 v1 响应中只返回一个可执行项目；多动作和多组需要后续提升协议版本。

### 3.2 App 当前可消费的饮食对象

```json
{
  "title": "训练日饮食建议",
  "body": "可直接展示给用户的简短正文",
  "source": "agent"
}
```

当前 App 没有热量、宏量营养素、禁忌依据或结构化餐次字段。如果 Agent 需要返回这些信息，双方应先扩展 Dart 模型和页面，不能只在服务端增加字段后假设 App 会展示。

### 3.3 尚未实现的训练后 Agent 调用

当前 App 保存 `SessionResult` 后只会重新调用 `fetchPlan` 和 `fetchNutrition`，没有单独的训练总结接口，也没有实时 WebSocket。

若 Agent 需要生成训练总结，建议先冻结一个最小调用：

```text
输入：UserProfileSnapshot + 本次 SessionResult + 必要的最近历史
输出：可展示总结 + 是否更新计划 + 更新后的计划（如有）
```

服务端应使用 `session_id` 保证幂等，重复提交同一训练结果不得重复调整计划。Agent 只能基于 App 提供的结构化事实生成解释，不得把缺失的质量字段推断成“动作正确”。

## 4. 当前没有实现的能力

以下能力目前尚未接入，Agent 端不能按“App 已支持”设计联调：

- Agent HTTP API、WebSocket 和正式请求/响应模型；
- 登录、用户 ID、鉴权、Token 刷新和多设备同步；
- 云端画像、计划、饮食和训练记录持久化；
- 训练中的 Agent 实时话术、语音对话或训练控制命令；
- 训练后的 Agent 总结和可靠的下次计划更新；
- 云端质量评分、卡路里估算或主要错误聚合；
- 原始图片、视频、逐帧关键点上传；
- 用户查看、导出或删除云端数据；
- iOS 原生训练桥和 iOS 安装包。

已有的 `docs/contracts/AI健身教练_前后端通信协议_v0.1.md` 是范围较大的通信草案，不代表 App 已实现其中的 REST/WebSocket、实时事件和 Agent 命令。首轮联调应先完成计划、饮食和训练后总结的最小闭环。

## 5. 需要 Agent 端确认并提供的内容

请 Agent/后端负责人提供同一份可执行接口说明，至少包含：

1. 开发和演示环境的 Base URL；
2. 鉴权方式，以及测试账号或开发期替代方案；
3. 计划接口的请求、成功响应、无训练响应和错误响应 JSON；
4. 饮食接口的请求、成功响应和拒绝个性化建议时的 JSON；
5. 训练后总结/计划更新接口是否本轮实现；
6. 超时、重试、限流和服务不可用的错误码；
7. `plan_id`、`plan_item_id` 和 `session_id` 的生成方及幂等规则；
8. `goal`、`experience`、`diet_preference` 等枚举是否沿用当前中文值；
9. 是否确需上传 `has_current_discomfort`，以及用户授权和服务端保存策略；
10. Agent 输出中哪些内容来自结构化事实，哪些只是生成式建议；
11. 计划更新成功后，App 应获得完整新计划还是仅获得 `changed=true`；
12. 一套可以直接用于 App 自动测试的固定请求/响应样例。

模型服务密钥必须保存在服务端，不能写入 Flutter 源码、APK、Git 仓库或移动端环境变量。

## 6. 建议的首轮联调顺序

1. Agent 先提供固定 JSON 的计划和饮食接口；
2. App 实现网络版 `CoachRepository`，完成超时和本地模板降级；
3. 双方确认计划响应沿用 App 已预留的 `exercise_id`，首批只支持 `squat/push_up`；
4. 真机走通“画像 → Agent 计划 → 真实训练 → 本地总结和历史”；
5. 增加训练后总结接口，以 `session_id` 做幂等；
6. 确认 Agent 真实保存新计划后，再在 App 中展示 `next_plan_changed=true`；
7. 最后再评估实时 WebSocket、语音和更完整的训练事件上传。

## 7. 当前验证状态

当前环境为 Flutter 3.47.6、Dart 3.13.5，已经完成：

```text
flutter pub get       成功
flutter analyze       No issues found
flutter test          11 个测试全部通过
flutter build apk     Debug APK 构建成功
```

Debug APK 输出位置：

```text
build/app/outputs/flutter-apk/app-debug.apk
```

与 Android 原生训练桥有关的冻结字段和状态语义，以 `docs/contracts/training_bridge_v1_frozen.md` 为准。Agent 网络接口尚未冻结；新增字段前应先更新共同协议、JSON 样例和双方测试。
