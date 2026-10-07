# Agent 端待办与 APP 联调验收

更新时间：2026-10-07

适用 Agent 仓库：`theone-latest/theone-latest`

适用 APP 仓库：`app/ai_fitness_coach`

## 1. 当前结论

APP 端的 Agent 计划、饮食、训练总结、聊天与记忆入口已经基本接通，客户端会：

- 使用本机持久化的 `installation_id` 作为 Agent `user_id`；
- 在用户明确开启“允许上传训练数据”后才同步画像、读取记忆或发送聊天；
- 请求计划、饮食、周回顾和训练总结时调用 `/api/app/v1/*`；
- 聊天与记忆暂时调用 Agent 已有的 `/api/chat`、`/api/memory*`；
- 对所有 Agent 请求携带同一个可选请求头：`Authorization: Bearer <AGENT_DEV_TOKEN>`；
- 聊天时附带当前计划和最多 10 条真实训练记录，不上传模拟训练、身体不适字段、视频、图片、逐帧骨架或原始 URDF；
- 支持查看 Agent 记忆和删除当前 `installation_id` 对应的服务端记忆。

APP 端已通过静态检查、Flutter 全量测试、真实 Agent 本地联调和 Android Debug APK 构建。当前影响“可直接使用”的主要事项在 Agent 服务端：补齐聊天/记忆鉴权，并配置可用的模型 API Key。

## 2. P0：补齐聊天与记忆接口鉴权

### 2.1 问题

`coach/app/mobile.py` 已经保护整个 `/api/app/v1/*` 路由：

- 设置 `FITNESS_APP_DEV_TOKEN` 后，必须传入完全一致的 Bearer Token；
- 未设置 Token 时，仅允许 `127.0.0.1` 或 `::1` 访问；
- 未配置 Token 的远程请求返回 `503 APP_ACCESS_NOT_CONFIGURED`。

但 `coach/app/routers.py` 中的以下用户数据接口目前没有鉴权，不能安全地暴露到局域网或公网：

- `POST /api/chat`
- `GET /api/memory`
- `POST /api/memory/profile`
- `POST /api/memory/delete`
- `GET /api/history`
- `POST /api/history/delete`

### 2.2 建议实现

将 `coach/app/mobile.py` 中现有的 `authorize` 提取到公共模块，例如 `coach/app/app_auth.py`，供 `mobile.py` 和 `routers.py` 共用。不要再实现第二套 Token 或第二种请求头。

短期保持现有 URL 不变，只给上面的聊天、记忆和历史接口增加 `Depends(authorize_app)`。这样 Agent 端完成后，APP 不需要改协议或重新设计页面。

鉴权行为应统一为：

| 服务端状态 | 请求来源/凭据 | 预期结果 |
|---|---|---|
| 已设置 `FITNESS_APP_DEV_TOKEN` | Token 正确 | 放行 |
| 已设置 `FITNESS_APP_DEV_TOKEN` | Token 缺失或错误 | HTTP 401，`code=UNAUTHORIZED` |
| 未设置 `FITNESS_APP_DEV_TOKEN` | loopback | 放行，便于本机开发 |
| 未设置 `FITNESS_APP_DEV_TOKEN` | 非 loopback | HTTP 503，`code=APP_ACCESS_NOT_CONFIGURED` |

错误体继续沿用 APP 已支持的结构：

```json
{
  "detail": {
    "code": "UNAUTHORIZED",
    "message": "开发访问凭据无效。",
    "retryable": false
  }
}
```

注意：这是比赛演示和可信局域网联调所需的“共享开发凭据”，不是生产级用户登录系统。生产部署仍需 HTTPS、用户会话/JWT、按用户授权和限流；不能把共享 Token 当作最终账号体系。

### 2.3 Agent 自带网页聊天

如果设置了 `FITNESS_APP_DEV_TOKEN`，当前 `coach/chat.html` 也会因为没有 Authorization 请求头而收到 401。可二选一：

1. 比赛期间以 APP 为唯一客户端，并在文档中说明网页聊天在启用 Token 后不可用；
2. 给网页开发工具增加 Token 输入框，仅保存到 `sessionStorage`，由统一的请求函数添加 Bearer 请求头。

不要把真实 Token 写进 HTML、JavaScript、Git 或构建产物。

## 3. P0：配置模型服务

Agent 当前默认模型配置为：

```json
{
  "base_url": "https://api.openai.com/v1",
  "model": "gpt-4.1-mini",
  "timeout_seconds": 90,
  "json_mode": true
}
```

模型请求使用 OpenAI 兼容的 `POST /chat/completions`。推荐通过环境变量注入，不在 `coach/config.json` 中提交真实密钥：

```powershell
$env:FITNESS_API_KEY = "<模型服务 API Key>"
$env:FITNESS_BASE_URL = "https://api.openai.com/v1"
$env:FITNESS_MODEL = "gpt-4.1-mini"
```

这里有两个完全不同的凭据：

- `FITNESS_API_KEY`：Agent 服务端调用模型供应商的密钥，只能存在服务端；
- `FITNESS_APP_DEV_TOKEN`：APP 调用 Agent 服务的共享开发凭据，APP 与 Agent 配置相同值。

必须分别配置，不能混用。未配置模型 Key 时，画像保存、记忆读取/删除和安全规则分支仍可能工作，但普通模型聊天、模型总结等请求会返回 503，不能视为完整联调成功。

## 4. 聊天与记忆契约

### 4.1 APP 当前实际调用

同步画像：

```http
POST /api/memory/profile
Authorization: Bearer <token>
Content-Type: application/json

{
  "user_id": "<installation_id>",
  "profile": {
    "goal": "strength",
    "experience": "beginner",
    "days_per_week": 3,
    "minutes_per_session": 20,
    "equipment": ["bodyweight"],
    "limitations": [],
    "dietary_preferences": [],
    "allergies": [],
    "medical_conditions": [],
    "preferred_language": "zh-CN"
  }
}
```

聊天：

```http
POST /api/chat
Authorization: Bearer <token>
Content-Type: application/json

{
  "user_id": "<installation_id>",
  "message": "今天适合练什么？",
  "context": {
    "app_profile": {},
    "current_plan": {},
    "recent_sessions": []
  }
}
```

读取记忆：

```http
GET /api/memory?user_id=<installation_id>
Authorization: Bearer <token>
```

删除记忆：

```http
POST /api/memory/delete
Authorization: Bearer <token>
Content-Type: application/json

{"user_id":"<installation_id>"}
```

### 4.2 当前持久化边界

Agent 的 `coach/app/history.py` 使用 `coach/data/history.sqlite3`，现有表包括画像、报告、记忆条目和聊天消息。当前通过 APP 调用可以确认：

- `memory/profile` 会持久化有限画像；
- `chat` 会保存用户消息和 Agent 回复；
- `memory` 会返回当前用户的画像/记忆/聊天摘要；
- `memory/delete` 会删除该 `user_id` 的 Agent 端数据；
- APP 本地画像和训练历史不会被上述删除操作清除。

聊天请求中的 `context.recent_sessions` 当前主要作为本次模型上下文使用，不会自动成为长期训练记忆。这不阻塞首轮聊天，但界面上的“记忆”若要长期展示训练事实，Agent 端后续应增加显式、幂等的训练事实持久化，建议按 `user_id + session_id` 去重，而不是从自然语言聊天中猜测训练记录。

### 4.3 服务端需要补强的输入约束

在不破坏现有 APP 的前提下，建议给旧接口补 Pydantic 请求模型和限制：

- `user_id`：非空，限制长度和字符集；
- `message`：去除首尾空白后 1～2000 字符；
- `recent_sessions`：最多 10 条；
- 拒绝超大 JSON 请求；
- 不接受客户端传入的模型指令、系统角色或任意数据库字段；
- 日志中不打印完整画像、聊天正文、Token 或模型 API Key。

## 5. 推荐修改文件

Agent 仓库内建议关注：

- `coach/app/mobile.py`：移除局部鉴权实现，改为导入公共鉴权依赖；
- `coach/app/routers.py`：为聊天、记忆和历史接口添加鉴权依赖；
- `coach/app/app_auth.py`：新增共享鉴权逻辑；
- `coach/chat.html`：若仍需网页调试，补开发 Token 请求头；
- `backend/tests/test_app_mobile_contract.py`：保留现有 `/api/app/v1/*` 鉴权回归；
- `backend/tests/test_chat_memory_auth.py`：新增聊天/记忆鉴权与持久化测试；
- `.env.example` 或 README：只记录变量名和示例，不写真实凭据。

Agent 工作树当前包含 E 同学尚未提交的语义修改及较多换行符差异。修改时应只编辑上述相关文件，不要全仓格式化或批量转换 CRLF/LF，也不要覆盖 `privacy_flow.py` 等已有成果。

## 6. 启动与联调配置

### 6.1 同一台电脑、ADB reverse

服务端只监听 loopback 时，可以不配置开发 Token：

```powershell
.\scripts\start_app_backend.ps1
adb reverse tcp:8000 tcp:8000
flutter run --dart-define=AGENT_BASE_URL=http://127.0.0.1:8000/api/app/v1/
```

### 6.2 局域网联调

生成一个足够长的随机 Token，然后分别配置服务端和 APP：

```powershell
# Agent 端
.\scripts\start_lan_backend.ps1 -HostIp <电脑局域网IPv4> -DevToken <随机Token>

# APP 端
flutter run `
  --dart-define=AGENT_BASE_URL=http://<电脑局域网IPv4>:8000/api/app/v1/ `
  --dart-define=AGENT_DEV_TOKEN=<同一个随机Token>
```

局域网 HTTP 仅限开发调试。对公网提供服务时必须使用 HTTPS，并更换为正式认证方案。

## 7. 自动化测试清单

Agent 端至少增加以下测试：

1. 未配置 Token 时，loopback 可访问聊天、画像、记忆和删除接口；
2. 配置 Token 后，缺失 Token 返回 401；
3. 配置 Token 后，错误 Token 返回 401；
4. 配置 Token 后，正确 Token 可同步画像；
5. 使用不调用模型的安全规则消息完成一轮聊天，并确认消息持久化；
6. `GET /api/memory` 能读到相同 `user_id` 的数据；
7. `POST /api/memory/delete` 后再次读取为空；
8. 未配置 Token 的非 loopback 请求返回 503；
9. A 用户不能通过接口操作 B 用户数据——生产认证实现后必须加入；共享开发 Token 阶段应明确该能力尚不成立。

服务端测试通过后，再执行 APP 的真实联调测试。若服务端启用了 Token，APP 测试进程也必须传入同一个测试 Token。

## 8. 人工验收步骤

1. 启动 Agent，确认能力接口返回 `model_configured=true`；
2. APP 的“Agent 连接”检测成功；
3. 未授权上传时，“教练”页不能同步画像、读取记忆或发送消息；
4. 开启授权后进入“教练”，画像同步成功；
5. 发送普通健身问题，获得真实模型回复；
6. 退出并重新进入 APP，历史聊天和记忆仍可读取；
7. 完成一次真实训练后再聊天，Agent 能在本次请求中使用该训练上下文；
8. 点击“删除 Agent 记忆”，服务端数据清空，但 APP 本地训练记录仍保留；
9. 使用错误 Token，所有受保护的 APP、聊天和记忆接口均被拒绝；
10. 检查服务端日志，确认没有输出 Token、模型 API Key 或完整隐私数据。

## 9. 完成标准

满足以下条件即可认为比赛版聊天与记忆链路可直接使用：

- 聊天、记忆、历史接口与 `/api/app/v1/*` 使用同一套鉴权；
- Agent 与 APP 的开发 Token 一致，错误凭据无法访问；
- 模型 API Key 有效，普通聊天和总结能够成功返回；
- 画像、聊天写入后可跨请求读取，删除后不可再读取；
- APP 在未授权时不上传数据，在授权后可完成同步、聊天、查看与删除记忆；
- 自动化测试和一次真机端到端验收通过；
- 仓库和构建产物中不包含真实 API Key 或开发 Token。

中期可以把聊天与记忆正式迁移为 `/api/app/v1/chat`、`/api/app/v1/memory*`，并增加版本化请求模型；首轮不建议一边联调一边强制迁移 URL，以免引入不必要的 APP 协议变更。
