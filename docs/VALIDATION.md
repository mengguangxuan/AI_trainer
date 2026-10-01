# 当前验证记录

日期：2026-10-01（工作区时间）。执行者：ZCode Agent（Flutter 开发 Agent）。

## 一、环境搭建结果（本机从零开始）

本机最初没有任何开发工具（无 flutter / dart / git / adb / Android SDK / Android Studio）。以下全部为本次自动安装，均为免安装解压版，位于 `D:\dev\`：

| 组件 | 版本 | 位置 |
|---|---|---|
| Flutter SDK | 3.47.5 stable（Dart 3.13.4） | `D:\dev\flutter` |
| Git | MinGit 2.50.1.windows.1 | `D:\dev\MinGit` |
| JDK | Temurin 17.0.20.1 | `D:\dev\jdk-17` |
| Android SDK | platform-tools 37.0.1、platform android-36、build-tools 36.0.0 | `D:\dev\android-sdk` |

`flutter doctor` 结果：**全部 7 项通过，No issues found**（Flutter、Windows、Android toolchain、Chrome、Visual Studio、Connected device、Network resources）。

环境变量（每次新开命令行需要重新设置，或由同学写入系统 PATH）：

```bat
set PUB_HOSTED_URL=https://pub.flutter-io.cn
set FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
set PATH=D:\dev\flutter\bin;D:\dev\MinGit\cmd;D:\dev\jdk-17\bin;D:\dev\android-sdk\platform-tools;%PATH%
set JAVA_HOME=D:\dev\jdk-17
```

## 二、本次实际执行的命令与结果

| 命令 | 结果 |
|---|---|
| `flutter --version` | Flutter 3.47.5 / Dart 3.13.4，满足 pubspec 要求（Dart ≥3.9） |
| `flutter doctor` | 全绿 |
| `flutter create --platforms=android --project-name ai_fitness_d_starter .` | 生成 android/ 目录 26 个文件；未覆盖 lib、test、pubspec.yaml |
| `flutter create --platforms=windows .` / `--platforms=web .` | 生成 windows/、web/ 目录用于本机验证 |
| `flutter pub get` | 成功，shared_preferences 2.5.5 等依赖解析完成 |
| `flutter analyze` | **No issues found** |
| `flutter test` | **3 个测试全部通过**（不适阻止训练入口、取消不计入完成、取消结果不携带动作数据） |
| `flutter run -d web-server --web-port 8321` | 应用成功编译并运行，通过浏览器完成交互验证（见下） |

## 三、修改文件清单与原因

| 文件 | 操作 | 原因 |
|---|---|---|
| `android/`（整个目录） | 新增 | 补齐 Android 平台工程（flutter create 生成） |
| `windows/`、`web/`（整个目录） | 新增 | 补齐桌面/Web 平台目录，用于无 Android 设备时的本机运行验证 |
| `test/widget_test.dart` | 生成后删除 ×3 | flutter create 每次都会生成与本原型无关的默认计数器测试（引用不存在的 MyApp），按交接要求删除 |
| `.idea/`、`*.iml`、`.metadata` | 自动生成 | flutter create 附带产物，已由 .gitignore 覆盖 |
| `docs/VALIDATION.md` | 更新 | 本文件 |
| `docs/validation-evidence/` | 新增 4 张截图 | 首次运行验收证据 |

**未修改任何 lib/ 源码和 pubspec.yaml**——GPT 交付的原型源码在真实 Flutter 工具链下一次通过编译、静态分析和全部单元测试，无需任何修复。

## 四、交互验证记录（浏览器自动化，Flutter Web 编译产物）

验证方式：`flutter run -d web-server` 编译运行 + 浏览器无障碍树读取控件 + 模拟点击。截图存于 `docs/validation-evidence/`。

| # | 验证项 | 结果 |
|---|---|---|
| 1 | 首次画像填写保存（默认值） | ✅ 进入首页，显示模板计划与统计 |
| 2 | 首页计划卡、来源标注（“本地示例模板”） | ✅ |
| 3 | 模拟完成训练 → 总结页（时长 35 秒、6 次、错误码中文解释、模拟来源标注） | ✅ |
| 4 | 完成后首页状态更新（已完成 1 次、连续 1 天、计划变为“继续练习：深蹲”） | ✅ |
| 5 | 历史页显示“已完成训练 · 模拟”记录 | ✅ |
| 6 | 模拟中途退出 → 总结页“本次训练未完成”，完成数仍为 1 | ✅ 取消不计入完成 |
| 7 | 历史页区分“训练未完成”与“已完成训练” | ✅ |
| 8 | 刷新页面（模拟重启）→ 画像与历史保留，统计仍为 1 次/1 天 | ✅ |
| 9 | 勾选“目前有身体不适”保存 → 计划变“暂停安排”，首页与计划页均**无开始训练按钮** | ✅ |
| 10 | 不适状态刷新后仍保留 | ✅ |
| 11 | 取消不适勾选 → 训练入口恢复 | ✅ |
| 12 | 饮食页显示模板建议与免责说明 | ✅ |

截图清单：

- `01-home-after-completed-session.png` 完成训练后的首页
- `02-mock-training-page.png` 模拟训练入口页
- `03-session-summary-completed.png` 训练总结页
- `04-history-page.png` 历史记录页

## 五、真机验证记录（2026-10-01 补充，小米 15 Pro · Android 16 · HyperOS V816）

手机连接与构建过程（首次 Android 构建的完整排障记录，对 C 合入团队仓库有直接参考价值）：

| 问题 | 根因 | 解决 |
|---|---|---|
| Gradle 构建卡死 20 分钟 | `services.gradle.org` 被墙，Gradle 发行版下载不动 | `android/gradle/wrapper/gradle-wrapper.properties` 改用腾讯镜像 `mirrors.cloud.tencent.com/gradle/gradle-9.3.1-all.zip` |
| 依赖解析失败 "不知道这样的主机" | DNS 间歇污染 `dl.google.com` | 重试即恢复；如再次出现可等几分钟再跑 |
| `compileDebugKotlin FAILED: Could not close incremental caches ... different roots: C:\... and E:\...` | **Kotlin 增量编译器不支持跨盘符**：项目在 E: 盘、Flutter 插件缓存在 C: 盘 | 把项目复制到 C: 盘同分区构建（`C:\Users\JingC.Gao\ai_fitness_build\`）。**团队仓库必须放在 C: 盘（或与 PUB_CACHE 同盘）** |
| `INSTALL_FAILED_USER_RESTRICTED: Install canceled by user` | HyperOS 默认禁止 USB 安装应用 | 手机 开发者选项 → 打开「USB安装」（需登录小米账号） |
| `input tap` 报 `INJECT_EVENTS permission` | HyperOS 默认禁止 ADB 模拟点击 | 手机 开发者选项 → 打开「USB 调试（安全设置）」，弹窗确认 |

实际执行结果：

- `flutter run -d 2b85d74d`：Gradle assembleDebug **373 秒构建成功**，产出 `app-debug.apk`。
- `adb install -r app-debug.apk`：**Success**，App 在真机安装并启动成功。

真机自动化交互验证（adb input + uiautomator 读取语义树，小米 15 Pro 实测）：

| # | 验证项 | 结果 |
|---|---|---|
| 1 | 首次画像保存 → 进入首页（模板计划、统计 0 次/0 天） | ✅ |
| 2 | 开始今日训练 → 模拟训练页（含"尚未连接摄像头"提示） | ✅ |
| 3 | 模拟完成 → 总结页（已记录、35 秒、6 次、错误码中文解释、模拟来源标注） | ✅ |
| 4 | 返回首页 → 已完成 1 次、连续 1 天、计划变"继续练习：深蹲" | ✅ |
| 5 | 记录页显示"已完成训练 2026-10-01 · 模拟" | ✅ |
| 6 | 强制杀掉 App 重启 → 直接进首页，画像与统计完整保留 | ✅ 持久化正常 |
| 7 | 模拟中途退出 → 总结页"本次训练未完成"，完成数仍为 1 | ✅ 取消不计入 |
| 8 | 勾选"目前有身体不适"保存 → 首页与计划页均无开始训练按钮，计划变"暂停安排" | ✅ |
| 9 | 取消不适勾选 → 训练入口恢复 | ✅ |

真机截图存档（`docs/validation-evidence/`）：05-引导页、06-首页、07-模拟训练、08-总结、09-历史、10-不适阻断。

**真机验证全项通过，D 模块原型达到首个真机验收 gate。**

## 六、仍未通过的 gate（更新）

1. `flutter build apk --release`：未执行（签名方案需 C 决定；debug 包已在真机全流程验证）。
2. Windows 桌面运行：需要开发者模式（符号链接权限），当前用户非管理员。
3. 真实摄像头、MediaPipe、WebSocket、Agent API 均未接入（按边界要求，不属于本阶段目标）。

## 七、给队友的阻断问题（与 HANDOFF.md 一致，此处为最新状态）

- **C**：Android 工程目录（`android/`）已在本原型生成并**已在真机构建成功**；合入团队仓库时由 C 接管并确认 Gradle 配置；`TrainingGateway` 待 C 用真实训练模块实现。**注意两条环境规则：① wrapper 已改腾讯镜像（国内网络必需）；② 仓库不能放在与 Flutter 插件缓存不同的盘符。**
- **Agent B**：`CoachRepository` 的 HTTP 版本需要真实的计划/饮食接口 JSON。
- **统筹**：`CONTRACT_DRAFT.md` 的三个数据对象字段需要正式确认冻结。
- **任何人**：不要把 API Key 写入源码；模拟数据必须保持来源标注。
