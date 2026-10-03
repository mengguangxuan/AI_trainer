# Training Bridge v1 草案（已归档）

> **本文件已归档，不再是当前协议。**
>
> v1 协议已于 2026-10-01 由 C、D 双方确认并冻结，当前版本见：
>
> **[training_bridge_v1_frozen.md](./training_bridge_v1_frozen.md)**
>
> 通道名以冻结版为准：`ai_fitness/training_v1`（本草案早期写的 `ai_fitness_coach/training` 已废弃）。
> 任何 Kotlin、Dart 或测试的桥接改动都应依据冻结版文件，不要依据本草案。

---

以下为归档原文（仅作历史参考）：

原生预留实现：

```text
native/android-training/app/src/main/java/com/google/mediapipe/examples/
poselandmarker/training/bridge/TrainingBridgeContract.kt
```

早期草案预留的 MethodChannel：

```text
channel：ai_fitness_coach/training
method：startTraining
```

数据类不依赖 Flutter SDK，只使用 StandardMessageCodec 可传输的 `Map<String, Any>` 类型。D 端工程到位后再增加实际 MethodChannel handler。

## 启动参数（早期草案）

```json
{
  "schema_version": "1",
  "session_id": "session_001",
  "exercise_id": "squat",
  "target_reps": 10
}
```

约束：

- `exercise_id` 只允许 `squat` 或 `push_up`；
- 每次会话只允许一个动作；
- `session_id` 由产品/会话层生成，原生训练模块只使用和回传；
- `target_reps` 必须为正整数。

## 返回结果（早期草案）

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

约束：

- `actual_reps` 必须来自端侧动作分析器；
- `status` v1 只允许 `completed` 或 `cancelled`；
- 取消结果可以携带真实次数，但产品层不得将其计为已完成训练；
- `duration_ms = ended_at_ms - started_at_ms`，后台暂停是否扣除需在最终契约中冻结；
- 返回结果不得包含原始图片、视频或可还原画面的视觉特征。
