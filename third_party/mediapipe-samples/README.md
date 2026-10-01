# MediaPipe 示例来源

Android 实时训练原型基于 Google 官方 MediaPipe Samples 的 Pose Landmarker Android 示例修改：

```text
https://github.com/google-ai-edge/mediapipe-samples/tree/main/examples/pose_landmarker/android
```

上游示例采用 Apache License 2.0，完整许可证见本目录的 `LICENSE`。从上游保留或改写的源文件继续保留原版权头。

团队新增的主要部分包括：

- 深蹲和俯卧撑的动作角度、阶段、计数与纠错规则；
- `ExerciseAnalyzer`、单元测试和离线冒烟测试；
- 实时训练 HUD 与结构化运动事件；
- 置信度过滤、可靠单侧选择和画面宽高角度修正；
- 端云隐私架构、通信协议和 Flutter 对接设计。

`pose_landmarker_lite.task` 来自官方 Pose Landmarker 示例资源，不应描述为团队自行训练的模型。

