# TECHNICAL_ROUTE

决策状态：`ACCEPTED / PHASE 1 IMPLEMENTED`

确认日期：2026-08-13

## 一句话结论

Egakium 正式采用 **官方 Chromium Embedded Framework（CEF）macOS ARM64 二进制发行包**作为网页渲染运行时；Egakium 自己拥有应用、Dock 身份、macOS 原生窗口、菜单和生命周期，CEF 只作为嵌入式 Chromium/Blink/V8 渲染基础设施。

不继续把完整 `Chromium.app` 当作产品入口，不通过删除或修改 Chrome UI 来制作 Egakium，也不自行维护 Chromium、Blink、V8 或 Content API fork。

## 决策背景

项目曾完成一个实验性启动链路：`Egakium.app` 启动本地编译的 `Chromium.app`，再通过 `--app=file://...` 打开白色 HTML 画布。该实验验证了 HTML 画布可以由 Chromium 渲染，但实际运行应用、Dock 身份、窗口体系和产品 UI 仍属于 Chromium。

这与产品目标不符。Egakium 的目标是一个由自然语言和语音驱动、以 HTML/DOM 元素构成的空间画布应用；Chromium 应是内部渲染引擎，而不是用户直接看到的浏览器产品。

## 已接受的技术路线

### 平台与发行形态

- 首个目标平台：macOS Apple Silicon（ARM64）。
- CEF 来源：CEF 官方发布的 macOS ARM64 二进制发行包。
- CEF 版本：`151.3.17+gf059e67+chromium-151.0.7922.138`，macOS ARM64 Standard Distribution。
- 官方下载：`https://cef-builds.spotifycdn.com/cef_binary_151.3.17+gf059e67+chromium-151.0.7922.138_macosarm64.tar.bz2`。
- 官方 SHA-1：`da0d745ac91cabc252eaa53c3c60c2aa60c73991`；工程固定 SHA-256：`b5302117aadb2255650cb721840d2512f0cb5e321b5ca446b1b07005afb948d2`。
- 版本、URL 与校验值的唯一工程记录为 `config/cef.cmake`。
- 默认不下载或编译 CEF/Chromium 源码；只有未来出现已确认且无法通过 CEF API 实现的底层需求时，才重新评估源码构建，而且需要新的用户决策。
- 正式 app bundle 必须自包含 CEF Framework、资源和所需 Helper app，不得依赖仓库外的 `Chromium.app`。

### 应用所有权

Egakium 自己负责：

- `Egakium.app`、Bundle Identifier、名称、图标和 Dock 身份；
- macOS 应用生命周期、原生窗口和菜单；
- CEF 初始化、关闭和浏览器实例生命周期；
- 内部资源加载、权限决策和 native bridge；
- Agent runtime、项目数据和产品逻辑。

CEF 负责：

- HTML/CSS 布局与绘制；
- DOM 和 V8 JavaScript；
- GPU 合成；
- Renderer、GPU、Network、Utility 等 Chromium 多进程能力；
- Web 平台能力以及 CEF 提供的页面生命周期和 IPC 接口。

### 目标运行结构

```text
Egakium.app
├── Egakium 主可执行文件
│   ├── macOS 生命周期与 NSWindow
│   ├── CEF 初始化与关闭
│   ├── Browser 实例生命周期
│   ├── 内部资源与权限策略
│   └── Agent / Native Bridge
├── Chromium Embedded Framework.framework
├── Egakium Helper.app
├── Egakium Helper (Renderer).app
├── Egakium Helper (GPU).app
├── 其他 CEF 要求的 Helper / Resources
└── Web 资源
    └── HTML / CSS / TypeScript 画布应用
```

运行时用户只看到 Egakium 的窗口和 Dock 图标。CEF 的 Renderer、GPU 和 Utility 等进程作为后台 Helper 运行，不显示普通 Chromium 浏览器窗口或独立 Dock 图标。

### 渲染模式

- 默认采用 **窗口内嵌、窗口化渲染**：CEF Browser 视图直接嵌入 Egakium 的 macOS 窗口。
- 第一阶段不采用 Off-Screen Rendering（OSR）。OSR 会额外要求像素/纹理传输、鼠标与键盘转发、IME、焦点、辅助功能和合成同步，不符合当前普通桌面画布需求。
- 不以 headless Chromium 截图或画面转发作为产品渲染链路。

### Web 应用与资源来源

- 当前白画布入口继续保留为 `src/canvas/index.html`，根 DOM 锚点继续使用 `#egakium-canvas`。
- 第一阶段已通过 bundle 内 `file://.../Contents/Resources/canvas/index.html` 加载白画布；这是当前实现，不是最终内部来源。
- 开发环境允许通过本地开发服务器加载页面，以支持前端热更新；具体前端框架尚未选择。
- 正式打包环境计划使用稳定的内部来源，例如 `egakium://app/index.html`，不长期依赖 `file://`。
- 内部 scheme 必须提供稳定 origin，并配合资源白名单、CSP、路径校验和明确的权限边界。
- HTML/CSS/TypeScript 的日常修改不应触发 CEF 或 Chromium 重编译。

### Native / Agent 边界

- 页面不得直接获得任意本机文件、进程或命令执行能力。
- Web 层与原生层、Agent runtime 之间使用异步、可版本化、白名单化的消息接口。
- 所有 native bridge 输入都必须校验来源、操作名、参数和权限。
- main agent、sub-agent、元素协议、持久化和模型接入尚未定型；其实现不得反向要求修改 Chromium 底层。

## 明确不采用的路线

### 不采用完整 Chrome 产品壳

`Chromium.app --app=<URL>` 只保留为已完成的实验记录，不是正式架构。它仍让 Chromium 拥有 Dock 身份、窗口体系和 Chrome 产品行为。

### 不魔改 Chrome UI

不通过删除地址栏、标签栏、书签、同步、扩展或 `chrome/browser/ui` 等代码来构建 Egakium。这会形成长期 Chromium 浏览器 fork，升级和回归成本与产品目标不相称。

### 不直接维护 Chromium Content embedder

不以 Chromium `content/public` 或测试用 `content_shell` 作为正式对外依赖。它们适合验证底层概念，但 API、bundle、Helper、沙盒和升级责任都需要项目自行承担；CEF 已经为第三方嵌入场景提供更合适的边界。

### 不自行构建 CEF/Chromium

当前没有修改 Blink、V8、Skia、网络栈或 CEF 本身的产品需求，因此不承担完整源码 checkout、数小时全量构建和持续上游合并成本。

## 开发与升级原则

- 前端业务代码与 CEF runtime 解耦；日常画布开发走热更新或资源刷新。
- 原生壳保持薄：只承载生命周期、窗口、CEF 集成、权限、bridge 和必要系统能力。
- CEF 使用固定版本，不在日常构建中隐式下载“最新版”。
- CEF 升级作为独立维护任务执行，必须重新验证 app bundle、Helper、沙盒、签名、页面渲染、输入、GPU、IPC 和权限行为。
- 大型 CEF 二进制、缓存和生成物默认不提交 Git；仓库只提交可重现版本与校验信息、应用源码和构建配置。

## 第一阶段验收标准

首个正式 CEF 白画布原型必须同时满足：

1. 生成可启动的 macOS ARM64 `Egakium.app`。
2. Dock、应用名称和 Bundle Identifier 都属于 Egakium。
3. Egakium 自己创建并拥有原生窗口。
4. 窗口内容只有覆盖完整内容区域的白色 HTML 画布。
5. 不出现 Chromium 地址栏、标签栏、书签栏、首次运行页或普通浏览器窗口。
6. CEF Renderer/GPU/Utility 作为 Egakium Helper 子进程运行，且不出现独立 Dock 图标。
7. app bundle 自包含运行所需 CEF Framework 和资源，不引用 `Chromium/checkout/.../Chromium.app`。
8. 修改白画布 HTML 后不需要编译 Chromium；开发态应能快速刷新。
9. 不修改 `Chromium/checkout/src/` 或任何 Chromium/CEF 底层源码。
10. 在上述链路验证完成后停止，不提前引入无限画布、AI、语音或 agent 框架。

截至 2026-08-13，上述第一阶段标准已在本机完成：生成并启动了 ARM64 `Egakium.app`，可视检查为纯白 HTML 内容区，无 Chrome UI；CEF Framework 与 Helper 全部自包含，GPU/Network/Storage/Renderer 子进程以 Egakium Helper 身份运行，关闭最后窗口后全部退出。正式签名、公证与 sandbox 不属于本阶段，并仍明确未完成。

## 迁移原则

- CEF 白画布原型已经通过验收；`chrome --app` 文件继续保留为历史实验基线，必须在文档中明确标记且不得继续扩展为正式架构。
- 已下载和编译的 `Chromium/` 暂时保留作为历史验证与排障基线。
- CEF 原型验证成功后，再由用户决定是否删除旧启动器、旧 `out/Egakium.app` 和完整 Chromium checkout；不得自动删除这些大体积但下载成本高的本地资产。

## 官方依据

- [CEF 官方项目](https://github.com/chromiumembedded/cef)：CEF 面向第三方应用中的 Chromium 嵌入场景，并提供稳定 API 与二进制发行包。
- [CEF General Usage](https://chromiumembedded.github.io/cef/general_usage.html)：多进程模型、应用结构、IPC 和 macOS bundle/Helper 要求。
- [CEF 官方示例项目](https://github.com/chromiumembedded/cef-project)：基于官方二进制发行包创建第三方 CEF 应用的参考工程。
- [CEF 官方二进制下载](https://cef-builds.spotifycdn.com/index.html)：选择并固定 macOS ARM64 发行版本的来源。

## 尚待后续任务确定

- 开发服务器与前端框架；
- `egakium://` scheme 的资源实现；
- Web/native/agent 消息协议；
- CEF sandbox 与权限策略；
- 签名、公证、更新和正式分发流程。
