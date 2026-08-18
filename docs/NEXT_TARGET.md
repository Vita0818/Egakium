# NEXT_TARGET

文档状态：CEF-only renderer cutover 已完成；当前没有经用户确认的下一业务目标
确认日期：2026-08-18
产品基线：v0.4（build 50）
identity 边界：全项目只使用 Egakium target/module/config/data identity；不提供 cutover 前兼容入口
完整产品合同：`docs/EGAKIUM_CANVAS_COWORK.md`

## 刚完成的目标

macOS Egakium 的主 Cowork presentation 现在是一个窗口中的原生水平 split：左侧
`CoworkCanvasHost` 直接嵌入官方 Chromium Embedded Framework（CEF）child browser，右侧继续原样
复用现有 `CoworkShell`。两侧消费同一个 `CoworkViewModel`、Session、Orchestrator、scheduler、
MessageBus、permission queue、EventLog 和 lifecycle；没有恢复独立 Canvas window、scene、action 或
第二套 runtime。

CEF 是唯一 Canvas renderer。已从 Canvas 路径删除：

- `WKWebView` / WebKit import；
- `WKContentWorld`、`WKNavigationDelegate` 和 content-rule adapter；
- `SessionCanvasRuntime` 的 injected CSS/JavaScript；
- `sessionStorage` layout override、MutationObserver、宿主 drag/resize/keyboard 实现；
- 600 ms Canvas-tree metadata monitor；
- WebKit file-URL loading、HTML error-page fallback 与任何 renderer switch。

当前 CEF 闭包固定为官方 macOS ARM64 Standard Distribution
`151.3.17+gf059e67+chromium-151.0.7922.138`。`EgakiumMac` build：

- 在 `config/cef.cmake` 固定 version/platform/archive/SHA-1/SHA-256；
- 校验 `.deps/downloads` 中 exact archive 和 `.deps/cef` 中 exact framework；
- 用 CEF 官方 CMake 定义编译 unmodified `libcef_dll_wrapper`；
- 直接编译 CEF 官方 external message pump；
- 使用官方 `CefScopedLibraryLoader`、`CefInitialize`、AppKit child `SetAsChild` /
  `CefBrowserHost::CreateBrowser`、`CefShutdown` 生命周期；
- 打包 versioned `Chromium Embedded Framework.framework` 和五个标准 sandbox Helper；
- 在所有进程注册 `egakium` custom scheme，主浏览器用 per-view memory-only request context；
- 只从 exact Session Canvas root 提供 regular、non-symlink 文件，阻断 network schemes 和 popup；
- 把官方 LICENSE/CREDITS 与项目 provenance 一起放进 App；
- 缺少或 hash/architecture 不符时构建失败，初始化失败时只显示 Canvas unavailable，不降级。

## 已保留的 renderer-independent 合同

- fresh Cowork 七事件 bootstrap 后，宿主仍无 provider、幂等、no-overwrite 地创建
  `.egakium/canvas/<SessionID>/index.html`；
- exact `@main` 仍通过现有 file/patch、WorkspaceLease、CapabilityLease、PermissionEngine 与 durable
  tool execution 直接编辑整页；ordinary worker 不得并发修改共享入口；
- provisional source DOM contract 仍是
  `#canvas > .egakium-element[data-element-id][data-x][data-y][data-width][data-height]`，子页面使用同
  Session 相对 `iframe sandbox="allow-scripts"`；模板 CSS 由 CEF 直接渲染，宿主不注入 DOM runtime；
- 全产品仍只有一个 `SessionCanvasElementTemplate` generic child document；successful ordinary
  `spawn_agent` 自动得到 host-chosen fresh ElementID、real workspace file 与 durable descriptor；
- descriptor 只是 spawn provenance，不是永久 ownership/lease；read-only child 仍不能编辑，recycle
  不删除，manual/legacy attach 才使用 identity-free prompt fallback；
- Chat/Code 仅隐藏 presentation 入口，底层功能与数据未删除；iOS 仍不链接 Cowork/CEF。

## 尚未实现，但不自动成为下一任务

以下能力仍是明确缺口，必须由用户选择范围后才能开始：

- durable CanvasID/ElementID、layout revision、event/projection 与冲突/恢复语义；
- 用户移动、resize、selection、z-order、pan/zoom 状态的 durable 设计；
- native bridge、Canvas mutation tool 或浏览器到宿主的授权动作；
- `@main → spawn(read_write) → exact-path delegation → worker edit → @main card integration` 的真实
  provider/App E2E；
- 双 Session、窗口关闭/重开、crash/replay、长 Session 与多元素性能的完整 GUI 验收；
- Developer ID nested signing、notarization、staple 与 Gatekeeper 的真实发行执行。

这些缺口不得通过重新引入 WKWebView、注入式 DOM adapter、自写浏览器 abstraction、截图 renderer、
外部 Chromium window 或临时 preview backend 来填补。如果 drag/resize/pan/zoom 等能力存在已审查且
可采用的官方/外部依赖，必须先按 dependency-first policy 选定并直接集成；接入受阻就报告 blocker。

## 当前验证事实

- pinned CEF Debug/Release wrapper、host bridge 与五个 sandbox Helper 编译通过；
- `xcodegen generate` 与完整 ARM64 `EgakiumMac` Debug/Release unsigned build 通过；
- 最终 App 包含 versioned CEF Framework、五个 Helper、LICENSE/CREDITS，主 executable/framework/
  Helpers 均为 ARM64，SwiftUI `NSApplication` 已安装 CEF/JCEF event + orderly-quit lifecycle；
- App 启动后出现 CEF GPU/network/storage subprocess，命令行含 `--seatbelt-client`，证明实际加载 CEF
  与 helper sandbox，而非仅源码声明；
- Canvas source scan 不再包含 `WKWebView`、`WKContentWorld`、`WKNavigationDelegate`、
  `SessionCanvasRuntime` 或 directory monitor；
- `SessionCanvasStoreTests` 12/12 通过；其余精确命令与后续完整回归见 `docs/TESTING.md`。

Debug build/runtime 证据不等于 Developer ID 公证发行完成，也不证明尚未执行的真实双 Session/
provider-driven element workflow。下一业务目标必须由用户明确指定。
