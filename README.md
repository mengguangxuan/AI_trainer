# 动姿智护 D 模块起点

这是一个**独立的 Flutter 原型源码**，用于在没有团队仓库的情况下先完成 D 负责的非实时产品流程。当前工作区没有 Flutter SDK，因此这里尚未编译或在真机运行；这不是已完成的比赛安装包。

## 已实现

- 首次画像填写与修改，本机保存；重启后尝试恢复。
- 首页、今日计划、饮食建议、历史四个入口。
- 计划中的深蹲目标通过 `TrainingLaunchArgs` 交给 `TrainingGateway`。
- `MockTrainingGateway` 返回完成或取消两种模拟结果。
- 总结、历史、本地连续训练天数；取消训练不会计入完成。
- 有当前不适时模板不自动提供训练入口；未知错误码不编造解释。
- `CoachRepository` 抽象接口，供 Agent B 的真实服务实现替换；服务失败时回退到标记过的本地模板。

所有模板和模拟训练在界面标明来源。**没有实现摄像头、MediaPipe、WebSocket、真实 Agent API 或正式训练评分。**

## 在装好 Flutter 的电脑上运行

1. 将整个目录解压到一个新文件夹；在该文件夹运行 `flutter --version`，确认 Dart 至少 3.9 / Flutter 至少 3.35，运行 `flutter doctor` 检查 Android 工具链。
2. 在该文件夹运行 `flutter create --platforms=android --project-name ai_fitness_d_starter .`，补齐本包没有的 Android 平台目录。不要使用覆盖选项；若工具询问覆盖现有 `lib`、`test` 或 `pubspec.yaml`，拒绝并检查。自动生成的默认计数器测试如存在，核对后删除。
3. 运行 `flutter pub get`、`flutter analyze`、`flutter test`，保存原始输出。
4. Android 手机打开开发者选项和 USB 调试，运行 `flutter devices`，再 `flutter run -d <设备ID>`。
5. 真机走通：填写画像 → 首页/计划 → 模拟完成 → 总结 → 历史 → 退出重开确认恢复；再试“模拟中途退出”与“当前不适”。
6. 可运行后由 C 负责构建和安装 APK：`flutter build apk --release`。正式提交包还需依比赛与团队规定处理签名和依赖清单。

## 文件用途

| 文件或目录 | 内容与负责人 |
|---|---|
| `lib/core/models/user_profile_snapshot.dart` | D 输入的结构化画像，跨组字段需共同确认 |
| `lib/core/models/training_launch_args.dart` | D → C 的训练启动参数草案 |
| `lib/core/models/session_result.dart` | C → D 的训练结果草案，允许缺少未测量字段 |
| `lib/core/models/training_plan.dart`、`nutrition_advice.dart` | D 展示计划与饮食的最小对象 |
| `lib/core/theme/app_theme.dart` | D 所有的全局颜色和组件样式起点 |
| `lib/features/product/data/local_product_repository.dart` | 本地画像及最近 30 条训练记录 |
| `lib/features/product/data/coach_repository.dart` | 可替换的 Agent B 服务边界 |
| `lib/features/product/data/template_coach_repository.dart` | 明确标记的离线示例模板，不代表 Agent 输出 |
| `lib/features/product/domain/product_controller.dart` | 状态、完成计数、连续训练与回退策略 |
| `lib/features/product/presentation/` | 画像、首页、计划、饮食、历史、总结及 D 产品入口 |
| `lib/features/training_contract/training_gateway.dart` | C 实现的训练模块桥接接口 |
| `lib/mocks/mock_training_gateway.dart` | 供 D 并行开发的模拟训练页面 |
| `lib/main.dart`、`pubspec.yaml` | 独立原型入口与依赖；并入团队工程时由 C 决定如何适配 |
| `test/product_rules_test.dart` | 对不适阻止自动训练、取消不算完成的规则验证 |
| `docs/` | 待确认接口、队友交接及 ZCode 指令 |

## 集成原则

先把 `docs/CONTRACT_DRAFT.md` 和三个 JSON 样例发给 C、Agent 组与统筹同学；他们确认后再当正式协议。真实训练由 C 实现 `TrainingGateway`，真实计划和饮食由 Agent B 提供接口并在 D 侧实现 `CoachRepository`。合入已有工程时不要覆盖 C 的路由、`pubspec.yaml`、Android 目录或训练文件。详见 `docs/HANDOFF.md`。

本地 `shared_preferences` 适合原型少量键值数据，不作为必须永久可靠的训练数据库；团队最终的数据保存方案由负责人决定。不要把模型 API Key 放入客户端。
