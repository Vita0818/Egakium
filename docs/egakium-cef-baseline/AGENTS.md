# Egakium 项目常驻上下文

本文件继承 `/Users/vita/Vitemis/AGENTS.md` 中的 Vitemis 通用 Agent 规则。若本文件与通用规则冲突，在不违反系统和用户指令的前提下，以更具体、更严格的规则为准。

## 必读顺序

执行任何源码、配置、构建脚本或测试修改前，依次阅读：

1. `/Users/vita/Vitemis/AGENTS.md`
2. `docs/CURRENT_STATE.md`
3. `docs/PROJECT_MAP.md`
4. `docs/ARCHITECTURE.md`
5. `docs/DO_NOT_BREAK.md`
6. `docs/TESTING.md`
7. `docs/NEXT_TARGET.md`（如果存在）

文档与源码、工程配置、测试或脚本冲突时，以当前源码和配置为准，并在最终报告中指出冲突。

## 工作目录检查

每轮开始在项目根目录执行：

```sh
pwd
git rev-parse --show-toplevel
git status --short
```

`pwd` 与 Git root 必须同时为：

```text
/Users/vita/Vitemis/Volans/Egakium
```

若不匹配，停止修改并报告路径问题。先区分用户已有改动与本轮改动，不得覆盖、回退或清理用户改动。

## 修改边界

本仓库已有正式的 macOS CEF + HTML 白画布原型，也保留了早期 `chrome --app` 实验链路。

- 白画布源码位于 `src/canvas/`。
- CEF 原生壳位于 `src/native/`，工程配置的唯一事实来源为根目录 `CMakeLists.txt`，命令行构建入口为 `scripts/build-cef-app.sh`。
- 根目录 `Egakium.xcodeproj/` 是真实存在、可跟踪的正式 Xcode 工程包，不得改回符号链接；使用 `scripts/generate-xcode-project.sh` 从 CMake 配置创建或刷新，target/Helper/bundle 规则仍以 CMake 文件为准。
- CEF 版本、平台、官方下载地址与校验值固定在 `config/cef.cmake`；变更该文件即属于一次 CEF 升级任务，必须重新完成全套验证。
- `.deps/` 是忽略的官方 CEF 下载包与解包目录，`build/` 是忽略的 CMake/Ninja/Xcode 生成目录；不得直接修改其中的上游或生成文件来实现产品功能。
- `packaging/macos/`、`scripts/build-macos-app.sh` 和生成的 `out/Egakium.app` 只属于保留的历史实验启动链路。
- `Chromium/` 是忽略的本地上游源码、依赖和构建产物目录，只作为历史验证与排障基线，不是正式 Egakium 构建依赖。
- 不修改 `Chromium/checkout/src/`、CEF、Blink、V8、Skia 或其他底层源码；不通过删改 Chrome UI 构建 Egakium。
- CEF 必须继续使用官方 macOS ARM64 二进制发行包，并在 app bundle 中自包含 Framework、资源和 Helper。
- 当前 CEF prototype 明确使用 `USE_SANDBOX=OFF`，且只有本地 ad-hoc/linker 签名；未经独立任务完成沙盒、正式签名和公证前，不得描述为可发布构建。
- 引入前端框架、AI/agent 框架、IPC、持久化或发布配置前，必须有明确的用户任务或已确认目标。
- 不得修改当前 Git root 之外的父仓库或相邻项目。

## 禁止事项

- 不执行破坏性 Git 操作，不删除用户未提交文件。
- 未经用户明文要求具体 Git 操作，不 add、不 commit、不 push、不创建 PR。
- 若用户要求提交，只提交当前 Git root 中与任务相关的文件，不处理父仓库、子仓库、submodule 或依赖 checkout。
- 不读取、打印或提交 `.env`、密钥、token、密码、cookie、session、私钥、证书或账号凭据。
- 不臆造尚未实现的 AI、语音、agent、元素协议、持久化或发布能力。
- 不把实验性的 `Chromium.app --app=<URL>` 描述为正式架构，不在该链路上继续扩展产品功能。
- 不自行创建 Chromium Content embedder，不以测试用 `content_shell` 作为正式产品壳。
- 不引入新依赖，不改构建脚本或测试源码，除非任务明确要求。

## 当前项目理解

- 项目阶段：官方 CEF ARM64 白画布原型已完成并通过本机验证；下一产品功能尚未确定。
- 目标平台：macOS Apple Silicon。
- 正式运行底座：官方 CEF `151.3.17+gf059e67+chromium-151.0.7922.138` macOS ARM64 Standard Distribution。
- 业务入口：`src/canvas/index.html`。
- 正式依赖入口：`cmake -P scripts/fetch-cef.cmake`。
- 正式 Xcode 入口：根目录实体工程包 `Egakium.xcodeproj/`；生成入口为 `scripts/generate-xcode-project.sh`，共享 scheme 为 `Egakium`。
- 正式命令行构建入口：`scripts/build-cef-app.sh`。
- 正式产物：`build/cef/src/native/Release/Egakium.app`。
- Xcode 开发产物：`build/xcode/src/native/{Debug,Release}/Egakium.app`。
- 核心链路：Egakium 自有 macOS app/CEF Views 窗口 → 窗口化 CEF BrowserView → bundle 内 HTML 白画布。
- 历史实验产物：`out/Egakium.app`（引用本地 Chromium 构建，只保留作历史基线）。
- AI、语音、main agent、sub-agent 和 HTML 元素框架：尚未实现。

## 文档索引

- `docs/CURRENT_STATE.md`：当前真实状态、未完成项和风险。
- `docs/PROJECT_MAP.md`：目录、模块、入口和产物地图。
- `docs/ARCHITECTURE.md`：总体架构、数据流、安全边界及结论来源。
- `docs/TECHNICAL_ROUTE.md`：已接受的 CEF 正式技术路线、排除项与验收标准。
- `docs/DO_NOT_BREAK.md`：工程、数据、协议、路径与回归禁区。
- `docs/TESTING.md`：环境、构建、测试、静态检查和验证边界。
- `docs/NEXT_TARGET.md`：临时下一目标；仅在目标具体且有效时存在，完成或失效后删除。

## 完成标准

- 说明实际阅读或检查过的源码、配置、测试和文档。
- 只修改任务范围内文件，并保留用户已有改动。
- 运行与风险相称的检查；纯文档任务至少运行 `git diff --check` 与 `git status --short`。
- 已完成的持久性变化应及时回写相关项目文档；无需更新时在最终报告说明原因。
- 未运行构建或测试时，在最终报告中明确说明。

## 最终报告

建议包含：`MODEL_CHECK_RESULT`、`PATH_CHECK_RESULT`、`FILES_WRITTEN`、`PROJECT_AUDIT_SUMMARY`、`DOCS_CONTENT_SUMMARY`、`VALIDATION_RESULT`、`UNCERTAINTIES`、`NEXT_RECOMMENDED_ACTION`。
