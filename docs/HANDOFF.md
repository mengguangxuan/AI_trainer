# 给队友的交接单

## 请 C 接收

1. 将 `lib/features/product/`、`lib/core/theme/`、`lib/core/models/`、`lib/features/training_contract/` 合入团队仓库。`main.dart` 仅供独立原型运行，不要覆盖团队入口。
2. C 保持团队路由表、`pubspec.yaml`、Android 目录的唯一修改权。确认是否加入 `shared_preferences`，然后在团队路由中挂载 `ProductShell(controller: ..., training: ...)`。
3. 用真实训练模块实现 `TrainingGateway`；完成、取消、异常都返回约定的 `SessionResult`。若用户仅按系统返回键，可以返回 null，D 不更新历史。
4. 对照 `docs/CONTRACT_DRAFT.md` 确认 `TrainingLaunchArgs` / `SessionResult` 字段，并给出一份真实示例。C 不需要修改 D 的页面。
5. 在目标 Android 手机验证摄像头权限、取消训练、无网络状态及可安装 APK。

## 请 Agent A/B 和统筹同学接收

1. Agent A 与 C 确认手机姿态处理和云端处理的唯一负责人、传输内容与错误码表；不要求 D 解析关键点。
2. Agent B 提供画像→计划、画像→饮食、训练结果→下一次计划的请求/响应 JSON，明确哪些响应可能为空，失败如何处理。
3. 统筹同学在 `CONTRACT_DRAFT.md` 上确认版本和负责人，决定是否上传“不适”字段；未确认前只保存在本机。
4. 模型服务密钥保留在团队服务端，不放入 App 源码或安装包。

## D 已做与未做

已做：画像、本地存储、首页、计划、饮食、训练入口桥接、模拟训练、总结、历史、连续训练的本地演示；模拟来源明确展示。

待在团队环境验证：Flutter 依赖下载、编译、测试、真机运行和 APK；当前工作区没有 Flutter SDK/Android 设备。真实 Agent API、摄像头和算法均未接入。

## 每天的最短验收

`flutter doctor` → `flutter pub get` → `flutter analyze` → `flutter test` → `flutter run -d <设备ID>` → 手工走通“画像→计划→模拟训练→总结→历史→重启恢复”。

如果任一命令失败，保存原始日志，先修复阻断项；不要仅凭浏览器截图认定 App 已可交付。
