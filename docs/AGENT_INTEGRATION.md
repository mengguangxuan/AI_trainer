# APP 与 Agent v1 联调说明

当前 APP 已接入 `theone-latest` 的 HTTP App Coach v1 契约。Android 继续负责 CameraX、MediaPipe、次数和训练中反馈；Flutter 在训练前后调用 Agent 服务。

APP 还接入了 Agent 当前提供的本地聊天与记忆接口：`/api/chat`、`/api/memory`、`/api/memory/profile` 和 `/api/memory/delete`。APP 使用本机持久化的 `installation_id` 作为 `user_id`，打开“教练”页时同步有限画像，发消息时附带当前计划和最多 10 条真实训练事实。身体不适、视频、图片、骨架和模拟训练记录不会进入聊天请求。

端侧视觉扩展链路已按 `App Privacy Flow v1` 预留：Video LLM、骨骼/URDF 适配器和复杂状态聚合器只向 Agent 提交语义 token、归一化统计和轨迹 token，不提交视频像素、图片、逐帧关键点或原始 URDF。客户端入口为 `AgentCoachRepository.submitPrivacyFlow`，服务端接口为 `POST /api/app/v1/privacy/flow`，完整字段见 [app_privacy_flow_v1.md](contracts/app_privacy_flow_v1.md)。

## 运行方式

默认地址为 `http://127.0.0.1:8000/api/app/v1/`。Android 模拟器或 USB 真机联调前执行：

```powershell
adb reverse tcp:8000 tcp:8000
```

也可以在构建时覆盖地址或开发凭据：

```powershell
flutter run --dart-define=AGENT_BASE_URL=http://127.0.0.1:8000/api/app/v1/ --dart-define=AGENT_DEV_TOKEN=...
```

正式服务必须使用 HTTPS，模型 API Key 只保存在 Agent 服务端。

## 本机已配置环境

- Flutter 3.47.6 / Dart 3.13.5：`D:\dev\flutter`
- Android SDK：`D:\dev\android-sdk`，包含平台 35/36、Build Tools 36.0.0、NDK 28.2.13676358、ADB。
- Java：`D:\dev\jdk-21.0.12.1+1`（Microsoft OpenJDK 21），Gradle 9.3.1。原 `D:\` 根目录 Java 安装会被 Gradle 误判为工程目录，不用于构建。
- 在 APP 仓库运行 `. .\scripts\env.ps1` 加载环境；没有改写系统 PATH。
- `scripts/build_debug.ps1` 检查代码、测试后构建真实调试 APK。
- 当前 SDK 的 `flutter analyze` 在中文路径下有 LSP 长度错误，使用 `dart analyze` 检查同一工程。
- Android Gradle 默认拒绝中文路径。构建脚本自动把源码复制到 `D:\dev\ai_trainer-build`（不搬动或删除原仓库），成功后将 APK 回传到原仓库 `build/app/outputs/flutter-apk`。
- 本机使用 Android 构建模式，关闭 Windows desktop 插件生成，避免未启用 Windows Developer Mode 时的符号链接错误。

## 首次联调

1. 在 Agent 仓库执行 `scripts/start_app_backend.ps1`，统一监听 loopback 的 8000 端口。
2. USB 真机开启调试并授权电脑，在 APP 仓库执行 `scripts/connect_android.ps1`。本机没有连接真机，摄像头训练尚需真机验收。
3. APP 首页右上角进入“Agent 连接”，检测协议；需要联网建议时打开训练数据授权开关并保存。
4. 服务端模型配置位于 `theone-latest/coach/config.json`，已创建空密钥配置。API Key 不进入 APP，不进入 Git。必须填入有效模型密钥后才会有真实生成结果。
5. 同一 Wi-Fi 联调使用现有 `theone-latest/scripts/start_lan_backend.ps1` 并设置开发 Token，在 APP 中填写同一个凭据与电脑内网地址。HTTP 仅调试版允许，远程无凭据会被拒绝。

连接成功只说明协议兼容。能力接口新增 `model_configured` 配置状态，不保证模型余额、权限或供应商响应正常。

底部“教练”页用于聊天；页面顶部可进入 Agent 记忆查看页，并可删除服务端保存的当前安装档案和聊天记忆。该删除操作不删除 APP 本地画像或训练历史。当前 Agent 的聊天/记忆接口属于本地开发接口，尚未实现独立用户鉴权，不能直接暴露到公网。

隐私 Flow 的连接成功还会返回 token-only 回执和本地透明红色轨迹叠加参数；`status=limited` 时 APP 只能提示观测受限，不能把它显示为动作正确。当前仓库的 `edge_catalog_v1` 只是可运行参考适配器，不等同于 TeleAI/智传网正式 SDK 或安全认证。

## 数据边界

- APP 只向 Agent 发送契约允许的画像字段；`has_current_discomfort` 永远留在本机。
- 训练记录保留原生 `SessionResult`，状态 `completed/cancelled/interrupted` 和 `source=real` 不被 Agent 改写。
- 训练总结是按 `installation_id + session_id` 幂等的附加记录，单独保存到本机。
- 计划、饮食分别请求、分别回退，某一个接口不可用不会覆盖另一个成功结果。
- 当前首轮只请求 `squat`；俯卧撑桥协议已支持，等产品计划明确开放后再加入可执行动作列表。
- `finished_at` 保留本地日历日期并带显式时区；history 排除当前记录、去重、最多 30 条。
- 网络结果使用请求版本校验，旧档案响应不能覆盖新档案；总结按会话关联，迟到结果不会写入其他训练页面。
- 训练结果保存后立即显示，Agent 总结在后台生成；失败状态保留，可在训练总结页用原会话重试。
- “记录”页可请求本周回顾；“Agent 连接”可清除当前服务与本机的总结缓存，不删除原始训练。
- 默认未授权上传，APP 使用本地模式。服务端规则与 APP 本地降级均为 template，但界面分别标注，不能误报为模型生成。
- 聊天与记忆沿用同一个数据授权开关；未授权时不会同步画像、训练事实或发送消息。
- 聊天会把最多 10 条真实训练事实作为本次上下文发送；当前 Agent 不会自动将这些 APP 训练事实长期写入 `history.sqlite3`。

## 服务不可用时

APP 保留原始训练和本地模板计划/饮食，首页显示回退状态；总结请求失败不会阻止训练记录保存。恢复服务后，可用相同 session 重试总结，服务端会按协议返回缓存结果或明确错误。
