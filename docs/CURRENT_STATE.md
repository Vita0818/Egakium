# CURRENT_STATE

最近核对：2026-08-28
Git root：`/Users/vita/Vitemis/Volans/Egakium`
产品基线：v0.4（build 50）

## 一句话状态

Egakium 已成为直接消费唯一 `/Users/vita/Vitemis/Intatis` checkout 的产品 overlay。仓内共享 runtime
snapshot 已删除；macOS/CLI 的 Code/Cowork 使用 `IntatisCodexRuntime` 官方
`CodexAppServerSession`，Egakium 自己继续拥有 UI、身份/配置、Canvas/CEF、CLI 表面和发行组装。

当前 Debug source/build/runtime-kit 验证通过；Developer ID signing、notarization、staple、Gatekeeper、
release packaging、clean-machine 和真实 provider E2E 尚未执行，因此状态不是正式 release。

## 实现来源

根 `Package.swift`：

- package dependency 只有 `.package(path: "../../Intatis")`；
- 本地 product 只有 `EgakiumCanvas` 与 executable `egakium`；
- 不再发布 `EgakiumCore`、`EgakiumAgentKernel`、`EgakiumCowork` 等复制产品。

`project.yml` 同时把 `Intatis: ../../Intatis` 作为 Xcode package source。macOS 直接链接保持产品功能所需
的 Intatis products；iOS 只链接 Chat subset。XcodeGen 后置脚本同步根 `Package.resolved` 到 workspace，
命令行与 Xcode 不再维护两套 resolution。

被删除的 tracked snapshot 共 680 个文件，覆盖 `Packages/`、`Vendor/`、`ThirdPartyStandards/`、旧 MCP
parity/conformance source 和重复 shared notices。任务前已有的 ignored build/cache/node_modules、
`Chromium/`、`.deps/`、`build/`、`OpenSource/` gitlinks 与 CEF 历史材料均保留。

完整范围见 [`INTATIS_RUNTIME_INTEGRATION.md`](INTATIS_RUNTIME_INTEGRATION.md)。

## 宿主身份

macOS、iOS 与 CLI 在任何共享 Intatis object 初始化前只安装一次：

```swift
IntatisHostApplication.configure(name: "Egakium")
```

共享源码因此继续派生并使用 Egakium 的：

- `EGAKIUM_*` 环境变量；
- `egakium.*` defaults/registry key；
- `com.vitemis.egakium.*` Keychain service；
- `Egakium` App Support 与 `egakium.json/jsonc`；
- `.egakium/` workspace/session/Canvas state；
- `__egakium_authorization_context` permission sidecar；
- `com.Vita0818.EgakiumMac` / `com.Vita0818.Egakium` bundle identity。

Intatis 模块名不改变产品品牌，不迁移或混用另一个 identity 的用户数据。

## macOS 产品面

唯一 shipping target 仍是 Developer ID 直接分发的 `EgakiumMac`。源码中 legacy
`EgakiumMacAppStore` target 不属于产品、默认构建或 release gate。

### UI

- 主 sidebar 可见 navigation item 只有 Cowork；初始 selection 也是 Cowork。
- Chat/Code enum case、views、view models、history、runtime 与恢复分支继续编译，只是 presentation-hidden。
- Cowork detail 仍是一个原生 `HSplitView`：左侧 `CoworkCanvasHost`，右侧既有 `CoworkShell`。
- 两侧消费同一个 `CoworkViewModel` 与 Session，没有独立 Canvas scene/window/action，也没有第二套
  runtime/scheduler/EventLog。
- 产品显示、命令、配置与提示文案仍是 Egakium。

### Runtime

- Chat 继续使用无工具的共享 `ChatLoop`。
- Code/Cowork 的 send/stream/approval/interrupt/shutdown 使用 `CodexAppServerSession`。
- product-specific tools 通过官方 `CodexRuntimeDynamicTools` 接入；执行仍受 shared tool registry、
  capability/workspace lease、permission、secret 与 durable execution 边界约束。
- 每个 Session 使用自己的 workspace、runtime root、credential、permission state 与 EventLog。
- 没有旧 `AgentLoop` production fallback、Codex protocol facade、MCP translator 或 parallel backend。

### Codex executable

Debug/Release App build phase 从 Intatis runtime kit 的 arm64 closure 取源，前后都调用 Intatis canonical
validator，并嵌入：

```text
EgakiumMac.app/Contents/Resources/CodexRuntime/arm64/
```

shipping App 不接受环境变量覆盖 sealed resource。当前验证的 runtime 是
`codex-cli 0.145.0-intatis.4`；exact version 与 derivation 不匹配会 fail closed。

### Canvas/CEF

- `Product/EgakiumCanvas` 是保留的产品专属模块，负责 Session index、generic child template 与 Canvas
  Skill resource。
- exact root `@main` 获得 `.egakium/canvas/<SessionID>/index.html`；普通 native child 得到自己的
  host-provisioned element file assignment，不修改共享入口。
- official CEF `151.3.17+gf059e67+chromium-151.0.7922.138` ARM64 仍是唯一 renderer。
- built App 含 versioned CEF framework、Resources、五个 standard sandbox Helper 与 notices。
- 不存在 WKWebView、WebKit injection、renderer adapter、preview backend 或 fallback。
- 当前仍没有正式 durable layout/event/native bridge schema；source HTML/CSS/iframe contract 保持既有
  provisional 状态。

## iOS 产品面

`EgakiumiOS` 仍是 Chat-only：

- 链接 `IntatisCore`、`IntatisProtocol`、`IntatisProviders`、`IntatisConversation`、
  `IntatisArtifacts`、`IntatisMultimodal`、`IntatisSharedUI`；
- 不链接 Tools、Knowledge、Skills、Permission、MCP、AgentKernel、Cowork、Codex Runtime、Canvas 或 CEF；
- 保留 Egakium Chat UI、provider config、history、hosted search/citations 与多模态 shared behavior。

2026-08-28 simulator universal build 通过，最终 symbol inventory 未发现上述 local-agent/runtime 模块。
App resources 中可出现完整第三方 notice 文本；notice 不表示对应 optional runtime 被链接。

## CLI 产品面

`egakium` 保留 Chat/Code/Cowork REPL、MCP 管理、诊断与离线 self-test。Code/Cowork production branch
进入 `codexRuntimeREPL`；显式开发 override `EGAKIUM_CODEX_RUNTIME` 仍接受 Intatis exact validation，
不是 release fallback。

## 当前验证

2026-08-28 snapshot 删除后：

- integration consistency script：通过；
- SwiftPM dump/build：通过；
- 完整 Swift tests：65 cases，57 passed，8 skipped（均为显式、可能付费的真实 provider smoke）；
- CLI offline selftest：通过；
- XcodeGen：通过；
- macOS arm64 Debug unsigned Xcode build：通过；
- built App runtime static validator：通过；
- CEF + Codex 临时 App 的 ad-hoc 内向外签名、integrity refresh、strict seal 与 execute-local：通过；
- CEF framework + five Helpers inventory：通过；
- iOS simulator Debug build：通过；
- version、identity、local-import/no-snapshot/no-fallback static checks：通过。
- macOS Debug App startup/Cowork-only single-window accessibility + screenshot smoke：通过。

未执行：真实 provider、workspace-backed Cowork split/Canvas interaction E2E、Developer ID、notarization、staple、
Gatekeeper、DMG/ZIP、clean-machine、Intel。精确命令见 [`TESTING.md`](TESTING.md)。

## 外部 checkout 状态与风险

本轮消费的 Intatis HEAD 为 `42cb5b36fb6be943ee7812aca3f8520c2e487b04`，但 sibling checkout 在任务
开始前/期间已有其他工作产生的 tracked 与 untracked 改动。Egakium 没有修改该仓库。local path
dependency 会编译当前文件，因此本轮成功证据对应“该 HEAD + dirty worktree”，不等于从 HEAD 单独可
重现。

正式 release 前必须由 Intatis owner 收敛为可审计 clean revision，并在 Egakium 重新执行完整构建、
测试、runtime/license/signing gates。不得重新复制 shared source 来掩盖 dirty dependency。

## 当前缺口

- 尚未获得 clean、committed Intatis source baseline 的跨机可重现证据；
- 尚未运行真实 provider/Codex conversation 与完整手工 UI 回归；
- 尚未完成 Developer ID/notarization/release 产物验证；
- Canvas durable element/layout/event/native bridge 仍未获准实现；
- 当前无获准的下一业务目标。
