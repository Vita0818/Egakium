# CURRENT_STATE

最近核对：2026-09-12
Git root：`/Users/vita/Vitemis/Volans/Egakium`
产品基线：v0.4（build 50）

## 一句话状态

Egakium 已成为直接消费唯一 `/Users/vita/Vitemis/Intatis` checkout 的产品 overlay。仓内共享 runtime
snapshot 已删除；macOS/CLI 的 Code/Cowork 使用 `IntatisCodexRuntime` 官方
`CodexAppServerSession`，macOS Cowork 完整右侧直接使用 presentation-only `IntatisCoworkUI`；Egakium
继续拥有 session/runtime、身份/配置、Canvas/CEF、非 Cowork-right UI、CLI 表面和发行组装。

2026-09-12 已修复 CLI、Code、Cowork 三处 `CodexBusinessToolHost.imageGenerator` 接线，完整 Swift
测试与 macOS ARM64 Release 构建通过。新 App 已使用同一 Developer ID、secure timestamp 和原有
Hardened Runtime/entitlements 完成全部嵌套签名，并安装到 `/Applications/Egakium.app`；安装目录的
strict seal、exact Codex App Server initialize 与运行中 CEF framework 加载均验证通过。
当前是本机自建安装，尚未执行公证、staple 或正式分发验收。已有旧 Cowork 会话仍停在 Canvas
preparing / `@main` inference unavailable 状态，其恢复未作为本次构建/安装修复完成项。

## 2026-09-12 修复与本机安装

- 修复仅增加五行宿主接线：CLI/Code 使用已有 `ProviderImageGenerationToolService(registry:)`，
  Cowork 使用已有 `registryBox.imageToolService()`；无新依赖、fallback、权限或数据格式变更。
- 完整 Swift tests：68 cases，60 passed、8 个真实付费 smoke skipped、0 failed；CLI offline selftest
  通过。最终 ARM64 Release 构建以 `BUILD SUCCEEDED` 结束。
- App 内 13 个 Mach-O 均为 arm64。CEF 五个 dylibs、framework、五个 Helpers、Codex 与主 App
  均由同一 Developer ID/Team ID 签署，保留 secure timestamp、Hardened Runtime、库校验和既有 JIT
  entitlement 边界。
- 本轮先尝试的 ad-hoc 签名虽然通过 strict seal 和 Codex initialize，却在真实 App 启动时被
  Library Validation 拒绝加载 CEF。现已通过一致的 Developer ID 签名解决；未关闭库校验或更换 renderer。
- 最终安装完成于 2026-09-12 15:03:38 +08:00，版本仍为 0.4/build 50。已从安装路径打开 App，确认
  Cowork 主窗口及实际加载的 bundle 内 CEF。原始 App 保存在
  `build/egakium-install-backups/20260912-142942-665198/Egakium.app`，用户配置和会话未被删除或重置。
- canonical Codex initialize 探针曾一次未返回 result，安装程序自动回滚；同一制品复验及最终安装
  目录复验通过。该一次性失败没有被忽略，也未修改 sibling validator。
- 旧会话可显示历史和项目设置，但 Canvas 仍 preparing、Main 未就绪；只读检查后未点击恢复/保存、
  改写历史、重绑模型或提交真实模型请求。这是待进一步定位的会话恢复问题，不能声称完整 Canvas E2E
  已通过。
- Intatis 在构建期间由其他工作修改，结束时已由其 owner 提交为 clean
  `ae589e17d90a217e43c55bb05ebb487b05e6b480`。本任务没有修改或提交 Intatis；本次构建从其此前 dirty
  工作树开始，不能表述为在该 clean revision 上完成了独立的全量发行回归。

命令与证据见 [`TESTING.md`](TESTING.md#2026-09-12-修复与本机安装)。

## 2026-09-12 修复前的构建与安装复核（历史诊断）

- 本机为 macOS 27.0、Xcode 27.0（27A5228h）、Apple Swift 6.4、arm64；Xcode first-launch check、
  XcodeGen 2.45.4、CMake 4.3.2、Ninja 1.13.2 可用，检查时可用磁盘约 309 GiB。
- integration/version gates、manifest dump、XcodeGen 与三个 `Package.resolved` 的 pin 对照通过。
- `swift build --disable-sandbox --disable-automatic-resolution` 失败，首个明确错误在
  `Apps/egakium-cli/Sources/CodexRuntimeCLI.swift`：构造 `CodexBusinessToolHost` 时缺少
  `imageGenerator`。日志还包含后续类型推断诊断，需修复首个错误后再确认是否仍独立存在。
- 使用独立 DerivedData、既有 exact package checkouts 和正常系统构建权限的 `EgakiumMac` arm64
  unsigned Debug 构建失败，错误在 `CodeViewModel.swift` 的同一构造调用。源码核对发现
  `CoworkViewModel.swift` 也缺少同一参数；本次编译在 Code 的错误处停止，不能声称已枚举全部错误。
- 该必填参数来自 Intatis 已提交的 `682c6fc`（2026-09-04，v0.72）。所需
  `ProviderImageGenerationToolService` / `registryBox.imageToolService()` 已存在于当前 Egakium
  宿主代码，修复方向是使用现有服务补齐三处官方 API 接线。本次仅排查，没有修改业务源码。
- CEF archive SHA-256 与 pin 一致；`scripts/prepare-cef-runtime.sh Debug` 通过，CMake 报告
  sandbox ON，Ninja 报告现有产物无需重建。Intatis source kit 和已安装 App 内的 exact Codex runtime
  均通过 canonical static validator。
- `/Applications/Egakium.app` 的主 executable 与 2026-08-31 的既有 Debug 产物逐字相同，版本仍为
  0.4/build 50。App、CEF framework 和五个 Helpers 都只有 linker ad-hoc signature，未封装 App
  resources；严格校验报告 `code has no resources but signature indicates they must be present`。
- 仅在临时 App 副本上按现有发行脚本顺序进行 ad-hoc 签名、保留现有 entitlements 并重建 Codex
  integrity inventory 后，完整 App strict seal 与 canonical `execute-local` 验证通过，后者包含
  exact version、derivation 和 App Server initialize。本次没有覆盖安装目录、申请 Developer ID
  签名、公证上传或运行完整 GUI/Canvas/provider E2E。
- Intatis HEAD 检查时仍为 `682c6fc`，但其工作树在排查期间被其他工作继续修改。Egakium 任务只读
  消费该依赖；本次结果不是冻结、clean checkout 的完整回归。后续修复验收需要稳定的依赖工作树。

完整命令、环境限制和未执行项见 [`TESTING.md`](TESTING.md#2026-09-12-构建与安装复核)。

## 实现来源

根 `Package.swift`：

- package dependency 只有 `.package(path: "../../Intatis")`；
- 本地 product 只有 `EgakiumCanvas` 与 executable `egakium`；
- 不再发布 `EgakiumCore`、`EgakiumAgentKernel`、`EgakiumCowork` 等复制产品。

`project.yml` 同时把 `Intatis: ../../Intatis` 作为 Xcode package source。macOS 直接链接保持产品功能所需
的 Intatis products，包括 `IntatisCoworkUI`；iOS 只链接 Chat subset。XcodeGen 后置脚本同步根 `Package.resolved` 到 workspace，
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
- Cowork detail 仍是一个原生 `HSplitView`：左侧 `CoworkCanvasHost`，右侧
  `IntatisCoworkContentView`。
- Egakium `CoworkSessionView` 只把既有 `CoworkViewModel` state/bindings/actions、thread source 与
  Project/MCP settings slot 薄映射给依赖 UI；Session/runtime/provider/workspace/MCP/permission/dynamic
  tools ownership不变，没有独立 Canvas scene/window/action 或第二套 runtime/scheduler/EventLog。
- 本地重复的 Cowork `CoworkShell` composition、Goal editor、inference accessory 与
  `ComposerAttachmentSurfaces.swift` 已删除；Chat/Code/Cowork attachment UI 直接来自 `IntatisSharedUI`。
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
- root与同 canonical workspace descendant的 successful completed App Server `fileChange` item会自动
  刷新 Canvas；failed/different-workspace/unclassified changes不自动刷新，manual Reload仍保留。
- 自动刷新已通过 policy/source/build验证；真实 provider `fileChange`→CEF event-to-paint尚未手工 E2E。
- official CEF `151.3.17+gf059e67+chromium-151.0.7922.138` ARM64 仍是唯一 renderer。
- built App 含 versioned CEF framework、Resources、五个 standard sandbox Helper 与 notices。
- 不存在 WKWebView、WebKit injection、renderer adapter、preview backend 或 fallback。
- 当前仍没有正式 durable layout/event/native bridge schema；source HTML/CSS/iframe contract 保持既有
  provisional 状态。

## iOS 产品面

`EgakiumiOS` 仍是 Chat-only：

- 链接 `IntatisCore`、`IntatisProtocol`、`IntatisProviders`、`IntatisConversation`、
  `IntatisArtifacts`、`IntatisMultimodal`、`IntatisSharedUI`；
- 不链接 Tools、Knowledge、Skills、Permission、MCP、AgentKernel、Cowork、`IntatisCoworkUI`、Codex
  Runtime、Canvas 或 CEF；
- 保留 Egakium Chat UI、provider config、history、hosted search/citations 与多模态 shared behavior。

2026-08-28 simulator universal build 通过，最终 symbol inventory 未发现上述 local-agent/runtime 模块。
App resources 中可出现完整第三方 notice 文本；notice 不表示对应 optional runtime 被链接。

## CLI 产品面

`egakium` 保留 Chat/Code/Cowork REPL、MCP 管理、诊断与离线 self-test。Code/Cowork production branch
进入 `codexRuntimeREPL`；显式开发 override `EGAKIUM_CODEX_RUNTIME` 仍接受 Intatis exact validation，
不是 release fallback。

## 最近一次完整成功记录（2026-08-31；历史证据）

2026-08-31 Cowork UI 接入后：

- integration consistency script：通过，并验证 `IntatisCoworkUI` product/import/content 与本地重复 UI
  均不存在；
- full Swift tests：68 cases，60 passed，8 个显式付费 smoke skipped，0 failed；其中 public integration
  suite 5/5，通过 `IntatisCoworkUIContract` v1 和 Canvas event-driven auto-refresh source contract gate；
- CLI offline selftest：通过；
- XcodeGen：通过；
- macOS arm64 Debug unsigned Xcode build（`ENABLE_DEBUG_DYLIB=NO`）：通过，包含现有 CEF/Codex build
  phases；主 executable 可见 `IntatisCoworkUI` symbols。
- built App exact Codex runtime static validation：通过。
- iOS simulator universal Debug build：通过；generated target graph与 final binary scan 均不含
  `IntatisCoworkUI`。

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

## 2026-08-31 外部 checkout 状态与风险（历史证据）

本轮消费的 Intatis HEAD 为 `4d4f6132146de18bc7d206fd8b27e4c702267710`，但 sibling checkout 在任务
开始前已有用户刚完成的 `IntatisCoworkUI`/SharedUI/adapter/manifest/tests/docs tracked 与 untracked
改动。Egakium 没有修改该仓库。local path
dependency 会编译当前文件，因此本轮成功证据对应“该 HEAD + dirty worktree”，不等于从 HEAD 单独可
重现。

完成时只读 inventory：14 tracked modified、1 tracked deleted、5 untracked；tracked binary diff
SHA-256 `887834f9e756801c30f1972136d58bb32978c5cef8422a78c12e7984b0072d42`，untracked path
inventory SHA-256 `cab0d7c5fda9fde6afa253d298b150c359c1f5e6210399b63e795c27cca87b5a`。

正式 release 前必须由 Intatis owner 收敛为可审计 clean revision，并在 Egakium 重新执行完整构建、
测试、runtime/license/signing gates。不得重新复制 shared source 来掩盖 dirty dependency。

## 当前缺口

- 已有旧 Cowork 会话的 root/inference/Canvas 恢复仍未通过；需要独立定位，不能以安装或 CEF 加载通过
  替代该业务验收。
- 本机 Developer ID 安装已经完成；正式公证、staple、Gatekeeper 与分发产物验收仍未完成。
- 尚未获得 clean、committed Intatis source baseline 的跨机可重现证据；
- 尚未运行真实 provider/Codex conversation 与完整手工 UI 回归；
- 尚未完成 Developer ID/notarization/release 产物验证；
- Canvas durable element/layout/event/native bridge 仍未获准实现；
- 跨 workspace element publication只完成设计评估，尚未实现；CEF仍只读取 primary Session root；
- 当前无获准的下一业务目标。
