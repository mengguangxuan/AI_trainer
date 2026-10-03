# Training Bridge v1（已冻结）

> 状态：**已冻结**（2026-10-01）。C、D 双方均已确认本版协议。通道名 `ai_fitness/training_v1`、`startTraining` 方法、`TrainingLaunchArgs`/`SessionResult` 外部结构以本文件为准；后续改动需提升协议版本（v2），不得静默修改 v1 字段语义。D 侧已完成：动作 ID 统一 `squat/push_up`、消费 `cancelled/interrupted` 结果、错误码中文文案对齐 §4、桥接测试覆盖全部状态与非法值。

## 1. 桥入口

```text
channel：ai_fitness/training_v1
method：startTraining
codec：StandardMessageCodec
```

`startTraining` 接收一个 Map，并在原生训练页结束后返回一个 Map。调用期间 Future 保持等待。v1 只支持 Android；iOS 不在本阶段范围内。

## 2. D → C：TrainingLaunchArgs

沿用 D 端外部结构，`schema_version` 是整数。

```json
{
  "schema_version": 1,
  "plan_item_id": "template_squat_01",
  "training_mode": "planned",
  "exercises": [
    {
      "exercise_id": "squat",
      "target_sets": 1,
      "target_reps": 6,
      "rest_seconds": 45
    }
  ],
  "coach_name": "AI 私教"
}
```

字段和约束：

| 字段 | v1 约束 | Android 用法 |
|---|---|---|
| `schema_version` | 必须为整数 `1` | 严格校验 |
| `plan_item_id` | 字符串或 `null` | 作为产品层元数据接收，v1 不参与识别 |
| `training_mode` | `planned` 或 `free` | 作为产品层元数据接收；两种模式均锁定本次动作 |
| `exercises` | 必须且只能有 1 项 | Android v1 一次启动一个动作 |
| `exercise_id` | `squat` 或 `push_up` | 与现有动作分析器 ID 一致；不使用 `pushup` |
| `target_sets` | 必须为整数 `1` | Android v1 尚无多组训练状态机 |
| `target_reps` | 正整数 | 显示目标并用于判断该组是否达标 |
| `rest_seconds` | 非负整数 | 接收但 v1 不执行组间休息，因为仅支持一组 |
| `coach_name` | 非空字符串 | 可用于标题展示，不参与识别和结果计算 |

`session_id` 不在 D 端现有启动结构中，由 Android 在成功解析参数后为每次调用生成唯一值，并在结果中返回。

## 3. C → D：SessionResult

沿用 D 端外部结构。示例中的空字段必须传 `null`，不得用空字符串或虚构值代替。

```json
{
  "schema_version": 1,
  "session_id": "unique-session-id",
  "status": "completed",
  "finished_at": "2026-10-01T20:00:00+08:00",
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

字段和计算规则：

| 字段 | v1 规则 |
|---|---|
| `schema_version` | 整数 `1` |
| `session_id` | Android 为本次调用生成的非空唯一字符串 |
| `status` | `completed`、`cancelled` 或 `interrupted` |
| `finished_at` | 带时区的 ISO 8601 字符串 |
| `duration_seconds` | 非负整数；以单调时钟计算实际训练时长，扣除主动暂停和进入后台的时间，再向下取整到整秒 |
| `exercises` | `completed` 时必须正好 1 项；训练已开始后的 `cancelled/interrupted` 也返回该动作的真实计数；训练开始前中断可返回空列表 |
| `exercise_id` | 原样返回本次的 `squat` 或 `push_up` |
| `completed_reps` | 端侧动作分析器给出的真实次数，不以目标次数代替，不因达到目标而截断 |
| `completed_sets` | 仅当 `status=completed` 且 `completed_reps >= target_reps` 时为 `1`，其他情况为 `0` |
| `quality_trend` | v1 固定为 `null`；当前算法没有可靠的跨次质量趋势聚合 |
| `main_error_code` | v1 固定为 `null`；实时纠错事件已存在，但尚未冻结“主要错误”的聚合规则 |
| `agent_summary` | v1 固定为 `null`；Android 桥不伪造 Agent 输出 |
| `next_plan_changed` | v1 固定为 `false`；只允许真实 Agent 保存新计划后由产品/Agent 层修改 |
| `source` | 原生真实识别结果固定为 `real`；模拟网关继续使用 `mock`，不得由原生桥返回 |

`duration_seconds` 来源于 Android 内部的毫秒精度计时；v1 外部结构只返回秒。若后续确需精细性能分析，应在 v2 新增字段，不在 v1 同时返回两套冲突时长。

## 4. 状态与退出语义

| 场景 | 返回 |
|---|---|
| 用户点击“完成训练” | `completed`；返回真实次数。未达到目标时 `completed_sets=0` |
| 用户点击“取消训练”并确认 | `cancelled`；D 不写入完成历史、不增加连续训练天数 |
| 用户按系统返回键并确认退出 | `cancelled`；行为与取消按钮一致，不返回 `null` |
| 相机权限拒绝、相机/模型初始化失败、训练被系统异常终止 | `interrupted`；D 不计为完成 |
| 启动 Map 类型错误、缺少必填字段、版本或取值不受支持 | MethodChannel `PlatformException`，错误码 `invalid_arguments` |
| 原生桥发生未分类错误 | MethodChannel `PlatformException`，错误码 `training_unavailable` |

D 端只有在 `status=completed` 时才保存为完成训练。`cancelled` 和 `interrupted` 即使携带真实次数，也不得进入完成数和连续训练统计。

## 5. v1 明确不支持的能力

- 一次启动多个动作；
- `target_sets > 1`、组间休息计时和自动切组；
- 自动生成质量趋势或主要错误；
- Android 原生生成 Agent 总结或修改下一训练计划；
- 上传原始图片、视频、逐帧关键点或可还原画面的视觉特征；
- iOS 原生训练桥。

这些限制不会阻塞首轮深蹲和俯卧撑闭环。未来若加入多动作、多组或 Agent 聚合，应提升协议版本，不能静默改变 v1 字段语义。

## 6. 双方确认项

确认后，C 与 D 应在同一提交基线上分别完成：

1. C 将 Kotlin 契约改为本文件的数字版本、通道名和嵌套结构，并实现 `completed/cancelled/interrupted` 返回；
2. D 保持现有 `TrainingLaunchArgs/SessionResult` 外部结构，将所有动作 ID 统一为 `squat/push_up`；
3. D 将系统返回键的 `null` 旧约定改为消费 `cancelled` 结果；
4. 双方各自增加相同 JSON 样例的编码、解码和非法参数测试；
5. 真机至少保存一次完成、一次取消和一次权限拒绝的实际返回 JSON。
