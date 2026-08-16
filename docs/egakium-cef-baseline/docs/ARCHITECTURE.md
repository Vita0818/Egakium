# ARCHITECTURE

最近自查日期：2026-08-13

## 总体架构

Egakium 当前已经落地“Egakium 自有原生壳 + 官方 CEF macOS ARM64 二进制 + HTML 画布”。Egakium 拥有 macOS 应用身份、生命周期和窗口创建逻辑；CEF 只提供嵌入式 Chromium/Blink/V8 渲染能力。

```text
Egakium.app（com.vitemis.egakium）
        │
        ├── EgakiumApplication / AppDelegate / 菜单 / 生命周期
        ├── CefInitialize / CefRunMessageLoop / CefShutdown
        └── CEF Views 顶层 CefWindow + CefBrowserView（Alloy）
                  │
                  ├── Egakium Helper：GPU / Network / Storage
                  ├── Egakium Helper (Renderer)：Blink / V8 / DOM
                  └── file://.../Contents/Resources/canvas/index.html
                                │
                                └── #egakium-canvas
```

现有 `out/Egakium.app → Chromium --app=file://...` 只作为已判定不适合正式产品的历史实验链路保留，与上述 CEF 正式产物彼此独立。

## 工程生成边界

根目录 `Egakium.xcodeproj/` 是实际的 Xcode 工程包，不是符号链接；它实际保存 `project.pbxproj`、workspace 设置和共享 scheme。为了避免手工维护两套 target/Helper/Framework 规则，`scripts/generate-xcode-project.sh` 先让 CMake Xcode generator 在被忽略的 `build/xcode/` 生成构建支撑，再把工程元数据同步到根目录，并把共享 scheme 的 `ReferencedContainer` 改为根目录工程自身。`CMakeLists.txt` 与 `src/native/CMakeLists.txt` 仍是工程定义的事实来源。

`scripts/generate-xcode-project.sh` 负责验证固定 CEF 依赖、生成 Debug/Release 配置并刷新根目录工程。共享 `Egakium` scheme 的依赖图包含主 App、五种 Helper、`libcef_dll_wrapper` 与 CMake 的重新配置检查；Xcode Build/Run 因此与命令行 CMake 构建使用同一套源码和 bundle 规则。

## 主要链路

当前主链路：

1. macOS 启动 `Egakium.app` 主可执行文件。
2. `EgakiumApplication` 初始化 Cocoa 应用，主进程通过 `CefScopedLibraryLoader` 从自身 bundle 加载官方 CEF Framework。
3. `EgakiumApp::OnContextInitialized` 创建 Alloy 风格的 CEF Views 顶层窗口和窗口化 BrowserView；没有 Chrome 产品 UI。
4. BrowserView 加载 `Contents/Resources/canvas/index.html`，当前来源是 bundle 内 `file://` URL；找不到文件时才使用内置纯白 data URL 作为失败兜底。
5. CEF 在后台启动 Egakium Helper Renderer/GPU/Utility 等子进程，直接向窗口内视图合成页面。
6. 用户只看到 Egakium 应用、原生标题栏和 HTML 白画布，不看到地址栏、标签栏、书签栏、首次运行页或普通 Chromium 窗口。
7. 最后一个 Browser 关闭后，Client 调用 `CefQuitMessageLoop`，主进程执行 `CefShutdown`，全部 Helper 随之退出。

当前实验链路仍记录在 `docs/CURRENT_STATE.md` 和 `docs/PROJECT_MAP.md`，不再作为架构主链路。

## 数据模型

尚无元素 schema 或项目持久化模型。当前唯一稳定 DOM 锚点为 `#egakium-canvas`；未来每个画布元素预计继续使用可寻址的 HTML/DOM 表达，但具体字段和协议尚未定义。

## 同步 / 通信机制

当前 CEF 原型没有产品级网络服务、native bridge 或 agent IPC。白画布只由主进程传入本地入口 URL，右键浏览器菜单被清空。

正式 CEF 壳中，Web/native/agent 通信应使用异步、白名单化、可版本化的桥接接口。AI、语音、main agent、sub-agent 与画布元素的具体消息协议尚未选择；引入前应先定义来源、身份、权限、输入校验、失败处理和版本兼容。

## 安全机制

- 不读取、记录或提交敏感凭据。
- 本地 `.env` 类文件默认忽略；若未来需要配置示例，只提交不含真实秘密的 `.env.example`。
- 当前正式画布使用 bundle 内 `file://`，没有获得自定义原生桥接权限；未来不长期依赖 `file://`。
- 正式 CEF 用户数据位于 `~/Library/Application Support/Egakium/CEF`；历史实验 Chromium profile 仍位于忽略的 `.runtime/chromium-profile/`。两者都不得提交浏览数据、cookie 或 session。
- 当前本机构建明确关闭 CEF sandbox，只适用于可信的本地白画布验证；加载不可信内容或加入 native bridge 前必须重新建立并验证隔离策略。
- 正式内部 scheme 必须具备稳定 origin、资源白名单、路径校验和 CSP。
- CEF/native bridge 不得向 Web 页面暴露任意文件、进程、命令执行或未校验的系统能力。
- 未来允许 HTML 或 AI 调用文件、麦克风、网络和系统能力时，必须建立明确的权限与来源边界。

## 模式开关 / 内核切换

- 正式运行时固定为 `config/cef.cmake` 锁定的官方 CEF macOS ARM64 二进制包。
- 不提供完整 Chromium、`content_shell` 或其他内核的运行时切换与自动降级。
- 当前 `EGAKIUM_CHROMIUM_EXECUTABLE` 只属于历史实验启动器，不进入正式配置面。

## 渲染边界

- 使用窗口化 CEF Browser 直接嵌入 Egakium 窗口。
- 当前实现使用 CEF Views 的 `CefWindow` 与 `CefBrowserView`，底层在 macOS 上创建原生窗口；运行样式固定为 Alloy，避免生成 Chrome UI。
- 第一阶段不使用 Off-Screen Rendering，也不使用 headless 截图/纹理转发。
- 不修改 Chrome UI；正式程序根本不启动 `chrome` 产品 target。
- 不直接维护 Chromium Content embedder；CEF 是 Egakium 与 Chromium 内部实现之间的稳定边界。

完整决策理由、排除项、升级原则和验收标准见 `docs/TECHNICAL_ROUTE.md`。

## 与文档/源码的关系

本文记录 2026-08-13 已落地并经本机验证的 CEF 白画布架构。未来的 `egakium://` scheme、native/agent bridge、无限画布和发布安全仍是未实现的下一阶段设计，不得提前当作现有能力。
