# APP Privacy Flow v1 客户端约定

APP 通过 `AgentCoachRepository.submitPrivacyFlow` 发送端侧感知结果，地址与鉴权沿用 `app_coach_v1`。

发送内容只有：

- Video LLM 输出的抽象语义 token；
- 骨骼适配器生成的 `urdf_token`、`trajectory_token` 和关节/帧/时长统计；
- 复杂状态 token（遮挡、低置信度、安全停止）；
- 当前动作、会话标识和显式隐私同意。

禁止把摄像头帧、视频文件、图片、base64、原始关键点、原始 URDF 或用户身份字段放进请求。`has_current_discomfort` 继续只在本机生效。

结果中的 `overlay.points` 是标准动作轨迹，APP 应在本地画面上用透明红色叠加；结果丢失时保留本地骨架和训练计数。`status=limited` 时只显示“观测受限/请调整机位”，不能显示为动作正确。

协议的隐私保证是“服务端不接收原始视频像素”，不是未经供应商审计的“任何 token 都绝对不可关联”。真正接入 TeleAI/智传网时，只替换端侧 token 适配器，不能放宽本协议的字段拒绝规则。
