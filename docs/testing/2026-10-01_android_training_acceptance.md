# Android 原生训练验收记录（2026-10-01）

## 自动验证

- 命令：`gradlew.bat --no-daemon testDebugUnitTest assembleDebug`
- 结果：冻结协议适配前构建成功；23 项单元测试全部通过。冻结协议适配后扩展为 26 项测试并重新通过，0 失败、0 错误。
- 覆盖范围：深蹲和俯卧撑动作分析、桥接参数与结果、会话状态、暂停时长扣除、取消以及纠错事件配对。
- APK：`native/android-training/app/build/outputs/apk/debug/app-debug.apk`

## 已完成的真机验证

- 设备：Xiaomi 24129PN74C。
- 启动参数：`session_id=acceptance_squat_001`、`exercise_id=squat`、`target_reps=5`。
- 真人连续完成 10 次深蹲，应用连续返回 `rep_index=1..10`，无缺号。
- 事件中的 `session_id` 与启动参数一致。
- 达到 5 次目标后继续按真实动作计数到 10 次，未伪造完成结果。

真机日志暴露了人物短暂离开画面时可能生成孤立 `motion.form_event end` 的问题。现已改为只对真正发出过的 `start` 生成 `end`，并增加回归测试 `suppressedErrorStartDoesNotProduceOrphanEndEvents`；修复后的完整构建已通过。

## 待完成的真机交互验收

最新 APK 构建完成后，手机 ADB 连接中断，以下项目等待设备重新连接后验证：

1. 暂停后画面显示“已暂停”，暂停期间不增加次数和训练时长；
2. 继续后必须重新保持起始姿势，暂停前的半次动作不能形成一次计数；
3. 点击“完成训练”后，Logcat 输出完整 `SessionResult`，状态为 `completed`；
4. 点击“取消训练”并确认后，状态为 `cancelled`，产品层不得记为完成训练；
5. 外部启动时隐藏动作切换和重置控件，只允许本次指定动作。

## 范围说明

iOS 因当前缺少 macOS/Xcode 硬件条件，不纳入本阶段开发和验收。Flutter MethodChannel 已按冻结协议接入同一份原生代码；合并后的 Flutter 单 APK 仍需在具备 Flutter SDK 的环境完成构建和真机验收。
