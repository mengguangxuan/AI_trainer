# D 模块接口草案 v0.1

**状态：待 C、Agent 组和统筹同学确认；不是已经冻结的团队协议。**

## 单一流程

1. D 保存 `UserProfileSnapshot`，请求计划与饮食建议。
2. D 从计划卡启动 C 的 `TrainingGateway.start(context, TrainingLaunchArgs)`。
3. C 返回 `SessionResult`；系统返回键不代表训练完成，需有明确状态。
4. D 保存结果并展示总结、历史与下一次计划。Agent B 是否真的更改计划由其结果决定。

本原型的 `TemplateCoachRepository` 和 `MockTrainingGateway` 均为模拟；界面显式显示来源。不可把模板计划、模拟次数和模拟纠错描述成模型识别结果。

## 今日需共同确认的字段

| 对象 | 生产方 → 消费方 | 已在源码中的字段 | 待确认 |
|---|---|---|---|
| `UserProfileSnapshot` | D → Agent B | goal、experience、days_per_week、minutes_per_session、has_equipment、has_current_discomfort、diet_preference | 健康字段是否进入云端；用户 ID 与授权 |
| `TrainingLaunchArgs` | D → C | plan_item_id、training_mode、exercises、coach_name | free 模式为空动作列表的处理；计划 ID 的来源 |
| `SessionResult` | C → D、Agent B | session_id、status、finished_at、duration_seconds、exercises、agent_summary、next_plan_changed、source | 错误码表、质量分是否确有测量、网络中断的状态 |
| `TrainingPlan` | Agent B → D | 目前只有本地模板对象，含 planId、stageName、headline、reason、item、source | Agent 的正式 JSON、版本、超时与缓存策略 |
| `NutritionAdvice` | Agent B → D | title、body、source | 是否返回禁忌依据、哪些情况拒绝个性化建议 |

**状态约定**：`completed` 才计入完成数和连续训练；`cancelled` 和 `interrupted` 只记为未完成。结果来源必须明确写 `real` 或 `mock`，缺失时展示“来源未确认”。未知错误码只显示“暂无解释”。不存在的质量分、卡路里和评分保持空值，不由界面编造。

## 真实服务接口还缺的决定

- Agent B 的计划、饮食接口地址、鉴权方式、请求响应样例和错误格式。
- Agent A 与 C 之间的关键点/动作识别/纠错边界；端侧跑什么，云端传什么。
- `next_plan_changed` 的产生者，以及新计划是由谁请求/刷新。
- 是否允许发送当前不适字段至服务端；默认只在本机保存，明确同意后才上传。
- 正式版 APK 不含模型服务密钥；由团队服务端保管。

## 示例

见 `contracts/*.json`。这些 JSON 是可讨论的样例，不是服务端现有接口。
