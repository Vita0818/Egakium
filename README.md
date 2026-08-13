# Egakium

Egakium 是一个以 Chromium Embedded Framework（CEF）为嵌入式渲染运行时、以 HTML/DOM 为画布和元素载体的 AI 原生空间工作台。

正式路线采用官方 CEF macOS ARM64 二进制发行包：Egakium 自己拥有应用身份、原生窗口和生命周期，CEF 只负责窗口内嵌的 HTML/CSS/JavaScript 渲染。AI、语音、main agent、sub-agent 和画布元素框架尚未接入。

## 仓库

- 本地根目录：`/Users/vita/Vitemis/Volans/Egakium`
- GitHub：`https://github.com/Vita0818/Egakium`
- 默认分支：`main`

## 当前状态

- GitHub 远端已配置为 `origin`。
- 已有一张无框架、无第三方依赖的 HTML 白画布。
- 已集成官方 CEF `151.3.17+gf059e67+chromium-151.0.7922.138` macOS ARM64 Standard Distribution，并把下载地址与 SHA-256 固定在 `config/cef.cmake`。
- 正式 CEF 原型已生成：Egakium 拥有自己的应用身份和窗口，bundle 内自包含 CEF Framework、资源与 Helper，只显示白色 HTML 画布。
- 根目录提供真实的 `Egakium.xcodeproj/` 工程包作为 Xcode 开发入口，内部实际包含 `project.pbxproj`、workspace 设置和共享 scheme；它不是符号链接。
- 正式构建产物位于 `build/cef/src/native/Release/Egakium.app`。
- 已完成一个 macOS `chrome --app` 启动实验，验证 Chromium 能加载白画布，也确认该方式仍暴露 Chromium 的 Dock/窗口身份，不符合正式架构。
- 旧 `out/Egakium.app` 仍是保留的历史实验产物，不是正式应用；是否清理旧壳和完整 Chromium checkout 由用户后续决定。
- AI、语音、main agent、sub-agent、无限画布与元素系统均尚未实现。
- 已接受的完整技术路线见 `docs/TECHNICAL_ROUTE.md`。

## Xcode 开发（推荐）

首次生成或需要刷新 Xcode 工程时运行：

```sh
./scripts/generate-xcode-project.sh
```

然后直接打开项目根目录中的工程：

```sh
open ./Egakium.xcodeproj
```

选择唯一的共享 scheme `Egakium`，即可使用 Xcode 的 Build 或 Run。Debug 与 Release 产物分别位于：

```text
build/xcode/src/native/Debug/Egakium.app
build/xcode/src/native/Release/Egakium.app
```

根目录 `Egakium.xcodeproj/` 是实际存在且可跟踪的 Xcode 工程包。生成脚本先在被 Git 忽略的 `build/xcode/` 完成 CMake 配置，再把 `project.pbxproj`、workspace 设置和共享 `Egakium` scheme 同步到根目录，并让 scheme 引用根目录工程自身。工程 target 和 bundle 规则的事实来源仍是根目录 `CMakeLists.txt` 与 `src/native/CMakeLists.txt`；修改这些配置后应重新运行生成脚本。

## 正式 CEF 白画布构建

首次准备官方 CEF 依赖：

```sh
cmake -P scripts/fetch-cef.cmake
```

依赖会放入被 Git 忽略的 `.deps/`，下载包必须通过固定 SHA-256 才会解包。生成或增量更新应用：

```sh
./scripts/build-cef-app.sh
```

打开正式原型：

```sh
open ./build/cef/src/native/Release/Egakium.app
```

日常修改 `src/canvas/index.html` 后再次运行构建脚本，只会把页面更新到 bundle；不会重新编译 Chromium/CEF，未改原生代码时 Ninja 会直接报告无需编译。

当前原型是本机开发构建，CEF sandbox、Developer ID 签名、公证和发布流程尚未完成，不应直接作为对外分发包。

## 历史 Chromium 实验（保留但不再扩展）

前提是本地 Chromium 已编译到：

```text
Chromium/checkout/src/out/EgakiumNative/Chromium.app
```

生成现有实验壳：

```sh
./scripts/build-macos-app.sh
```

该产物会启动完整 Chromium，因此只用于保存历史验证，不应继续扩展为正式产品。

如需重现实验，可以在 Finder 中打开 `out/Egakium.app`，或者手动执行：

```sh
open ./out/Egakium.app
```

实验启动器默认读取 `src/canvas/index.html`。该白画布会继续复用于正式 CEF 原型。

## 文档

- `AGENTS.md`：项目工作规则与修改边界。
- `docs/CURRENT_STATE.md`：当前真实状态与风险。
- `docs/PROJECT_MAP.md`：仓库结构与模块地图。
- `docs/ARCHITECTURE.md`：架构与关键链路。
- `docs/TECHNICAL_ROUTE.md`：CEF 正式路线、边界、排除项与验收标准。
- `docs/DO_NOT_BREAK.md`：不可破坏的约束。
- `docs/TESTING.md`：构建、测试和验证入口。

仅在已有具体下一目标时创建 `docs/NEXT_TARGET.md`。
