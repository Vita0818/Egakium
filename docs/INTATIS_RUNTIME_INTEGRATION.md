# Egakium → Intatis Runtime 直接接入报告

文档状态：当前迁移事实与维护合同
完成日期：2026-08-28
Egakium 产品版本：v0.4（build 50）
Intatis 跨项目宿主 API：v1
Intatis Codex executable：`codex-cli 0.145.0-intatis.4`

## 结论

Egakium 已删除仓内复制的 Intatis 共享实现，改为通过 SwiftPM local path dependency 直接编译
`/Users/vita/Vitemis/Intatis` 的唯一源码，并通过 `IntatisCodexRuntime` 的官方
`CodexAppServerSession` 启动 Code/Cowork。迁移改变的是共享实现来源，不改变 Egakium 的产品身份、
配置与数据命名空间、macOS 单窗口 Cowork 布局、CEF Canvas、隐藏但保留的 Chat/Code 产品面、iOS
Chat-only 边界或 CLI 命令身份。

不存在第二套 production agent loop、Codex protocol facade、MCP translator、preview backend 或旧
Egakium runtime fallback。Intatis 不可解析、v1 合同不匹配、exact Codex executable 不可验证或 CEF
不可组装时，构建或对应能力明确失败。

## 当前所有权

```text
/Users/vita/Vitemis/Intatis                    唯一共享实现 checkout（下游只读）
├── Packages/Intatis*                          Core/Protocol/Providers/…/Cowork
├── Packages/IntatisCodexRuntime               Codex App Server 宿主 API
├── .intatis/runtime-kit/0.66/CodexRuntime     exact Codex executable kit
└── ThirdPartyNotices                          共享依赖的 provenance/license

/Users/vita/Vitemis/Volans/Egakium             Egakium 产品 overlay
├── Apps/EgakiumMac                            macOS host、产品 UI、CEF lifecycle
├── Apps/EgakiumiOS                            iOS Chat-only host
├── Apps/egakium-cli                           Egakium CLI host
├── Product/EgakiumCanvas                      Canvas store/template/Skill
├── Apps/EgakiumMac/CEF                        pinned official CEF 最薄接线
├── ThirdPartyNotices                          Egakium 独有 CEF/JCEF/Skill 声明
├── Package.swift                              `.package(path: "../../Intatis")`
└── project.yml                                XcodeGen 的同一路径依赖与 App bundle 接线
```

Egakium 不再拥有 `Packages/Egakium*`、`Vendor/`、`ThirdPartyStandards/` 或原 MCP parity/conformance
source snapshot。旧文档中出现这些路径时，只能作为迁移前历史或 Intatis 当前对应实现的语义说明，
不能据此恢复副本。

## SwiftPM 与产品依赖

根 `Package.swift` 只发布：

- `EgakiumCanvas`：Egakium 产品专属 Canvas library；
- `egakium`：CLI executable。

根 package 的唯一直接 package dependency 是：

```swift
.package(path: "../../Intatis")
```

macOS 与 CLI 为保持既有完整产品行为，直接消费当前第一方 Intatis products：

- `IntatisCore`
- `IntatisProtocol`
- `IntatisProviders`
- `IntatisConversation`
- `IntatisArtifacts`
- `IntatisMultimodal`（macOS）
- `IntatisSharedUI`
- `IntatisTools`
- `IntatisKnowledge`
- `IntatisSkills`
- `IntatisPermission`
- `IntatisMCP`
- `IntatisMCPStdio`（Developer ID macOS/CLI）
- `IntatisAgentKernel`
- `IntatisCowork`
- `IntatisCodexRuntime`

`IntatisCodexRuntime` 的 v1 清单是稳定跨项目宿主合同。其余第一方 products 是 Egakium 保持既有
功能所需的共享产品面；它们直接来自同一 Intatis checkout，没有在 Egakium 中重新封装或复制。
升级时必须同时编译回归，不得把当前额外 public declaration 默认为永久 v1 ABI。

iOS 只链接 `IntatisCore`、`IntatisProtocol`、`IntatisProviders`、`IntatisConversation`、
`IntatisArtifacts`、`IntatisMultimodal` 与 `IntatisSharedUI`；没有 Tools、Knowledge、Skills、Permission、
MCP、AgentKernel、Cowork、Codex Runtime、EgakiumCanvas 或 CEF target linkage。

## 宿主身份与数据边界

macOS、iOS 和 CLI 都在构造任何 Intatis object 前执行一次：

```swift
try! IntatisHostApplication.configure(name: "Egakium")
```

之后共享实现从 `IntatisHostApplication.identity` 派生 Egakium 的 namespace，而不是写死或另建替换表。
因此当前行为继续使用：

- App Support/config/data stem：`Egakium` / `egakium`；
- environment prefix：`EGAKIUM_*`；
- UserDefaults/registry prefix：`egakium.*`；
- Keychain service：`com.vitemis.egakium.*`；
- workspace/session state：`.egakium/`；
- permission sidecar：`__egakium_authorization_context`；
- bundle identifiers：`com.Vita0818.EgakiumMac` 与 `com.Vita0818.Egakium`。

这不会探测、合并或迁移 Intatis 或 hard-cutover 前其他 identity 的用户数据。每个 session 继续拥有
独立 workspace、runtime root、credential、permission state 与 EventLog。

## Production runtime 路径

Code/Cowork 的生产 send、stream、approval、interrupt 和 shutdown 都由
`CodexAppServerSession` 负责；项目工具通过官方 `CodexRuntimeDynamicTools` extension 注册。
Chat 继续使用无工具的共享 `ChatLoop`，不被强行改成 agent runtime。

开发期默认 runtime source 是：

```text
/Users/vita/Vitemis/Intatis/.intatis/runtime-kit/0.66/CodexRuntime/arm64
```

`scripts/embed-intatis-codex-runtime.sh` 在 macOS build 中：

1. 用 Intatis 的 canonical validator 验证 source kit 的 architecture、manifest、version 与 derivation；
2. 将 exact closure 复制到 `EgakiumMac.app/Contents/Resources/CodexRuntime/arm64/`；
3. 再次验证 sealed App 内的 destination；
4. 任一检查失败即使 build 失败。

shipping-identity App 总是消费自己的 sealed resource，环境变量不能覆盖它。CLI 只允许通过
`EGAKIUM_CODEX_RUNTIME` 显式选择开发 executable，最终仍由 Intatis runtime 的 exact
version/derivation 验证拒绝错误二进制。不存在 PATH、Homebrew、sibling checkout 或旧 runtime fallback。

2026-08-28 验证的 arm64 closure SHA-256：

| 文件 | SHA-256 |
|---|---|
| `codex` | `9d5d81ef622f5bf7bc288837f2cd825fdd686dfe770109a0e9218cd087c90c74` |
| `runtime-manifest.json` | `881b12b23138f5fedc1e515a5afa53c0b6072ce133474b1ed252e4189a44cf3b` |
| `SHA256SUMS.txt` | `ed4d0fc7193d38d518bcc9bdcd043381b27312aaebe43e0fb0bfce1aa2704e08` |

这些 hash 是本次工作树验证证据，不取代 Intatis manifest/derivation 校验，也不自动授权将来升级。

## Egakium Canvas 与 UI 保留

Canvas 是产品专属 overlay，不属于共享 Intatis runtime：

- `Product/EgakiumCanvas` 继续创建并保护
  `.egakium/canvas/<SessionID>/index.html` 与 generic child document；
- `CoworkSessionView` 仍以单一 `HSplitView` 组合左侧 `CoworkCanvasHost` 与右侧既有 Cowork harness；
- 两侧消费同一个 `CoworkViewModel`/Session，没有第二套 runtime、scheduler 或窗口；
- `CoworkCanvasHost` 仍只创建 `EgakiumCEFView`，官方 CEF 仍是唯一 renderer；
- exact root `@main` 收到 Session Canvas 路径；native child thread 获得 host-provisioned 的独立 element
  document assignment，不并发修改共享 `index.html`；
- macOS sidebar 仍只显示 Cowork，Chat/Code enum、view、runtime 与历史路径仍编译保留；
- 产品字符串、命令、bundle、配置与界面品牌仍为 Egakium，不向用户暴露 Intatis 品牌。

CEF `151.3.17+gf059e67+chromium-151.0.7922.138` ARM64 framework、五个标准 sandbox Helper、
external message pump、strict `egakium://canvas` scheme 与 notices 继续由 Egakium 自己构建/打包；未增加
WKWebView/WebKit 或其他 renderer fallback。

## 删除范围与有意保留项

迁移在证明旧目录已退出 build graph 后，删除了 680 个父仓库 tracked snapshot 文件：

- `Packages/` 下的复制 shared runtime/source/tests；
- `Vendor/` 下的复制 third-party source；
- `ThirdPartyStandards/` 下随共享 runtime 复制的标准材料；
- `Tests/MCPBM25ParityOracle/` 与 tracked `Tests/MCPConformance/` source；
- 28 份已由 Intatis `ThirdPartyNotices` 提供的重复声明。

有意保留：

- Egakium 的 `Apps/`、`Product/EgakiumCanvas`、CEF host、UI、资源、CLI 与产品测试；
- Egakium 独有 CEF/JCEF/Skill notices；
- `.gitmodules` 和 `OpenSource/` 的 26 个 mode-160000 gitlink；
- 任务前已有且被忽略的 `Chromium/`、`.deps/`、`build/`、`.build/`、node_modules/cache；
- `docs/egakium-cef-baseline/` 历史快照。

被忽略的 cache 没有进入 manifest、project 或 active import graph；迁移没有为了“目录看起来为空”而
删除用户/本地构建资产。

## 验证证据

2026-08-28 在删除 snapshot 后已通过：

- `scripts/check-egakium-intatis-integration.sh`；
- `swift package --disable-sandbox dump-package`；
- `swift build --disable-sandbox --disable-automatic-resolution`；
- `swift test --disable-sandbox --disable-automatic-resolution`：65 cases，57 passed，8 个需真实付费
  provider 的 smoke 按显式环境门跳过；
- `.build/debug/egakium selftest`：Chat、Code tool read/write、Cowork inference profile 均通过；
- `xcodegen generate`；
- `EgakiumMac` Debug arm64 unsigned Xcode build；
- built App 内 exact Codex Runtime static validation；
- 临时 App 副本的 CEF + Codex 内向外 ad-hoc signing、integrity refresh、strict outer seal 与
  `execute-local` App Server initialize validation；
- built App 的 CEF framework 与五个 standard Helper inventory；
- `EgakiumiOS` Debug simulator universal build；
- iOS target/product/symbol inventory 不含 local-agent/Codex Runtime/CEF 能力。
- built macOS Debug App 实际启动：单 Egakium window、Cowork-only sidebar、无独立 Canvas window 的
  accessibility/screenshot smoke 通过。

本次没有运行真实 provider 请求、workspace-backed Cowork 左右分栏/Canvas 全功能 E2E、真实 Developer
ID signing、notarization、staple、
Gatekeeper、DMG/ZIP release、clean-machine 或 Intel build。Debug App build 证明组装，不等于 release 完成。

## Intatis checkout 与可复现性

迁移时消费的 Intatis HEAD 为
`42cb5b36fb6be943ee7812aca3f8520c2e487b04`。该 sibling checkout 在迁移期间已有其他任务产生的
未提交/未跟踪修改，Egakium 任务没有修改 Intatis。因为 SwiftPM local path dependency 总是读取路径
处当前文件，当前验证结果对应“该 HEAD + 当时 dirty working tree”，不是仅由 HEAD 可重现的发行 pin。

完成时捕获的 external state：123 个 tracked modified files、0 deleted、0 added、2 untracked files；
tracked binary diff SHA-256 为
`62722284c7136df497be9921a698d35cc11a1563c2a2837d3135aa7c459ad9d0`，untracked path inventory SHA-256
为 `dd9c1e2cf0a292a5354a1453d0f871c9cce8b22fbf1389107803134f4a92ae7f`。两个 untracked paths 是
`Packages/IntatisCore/Sources/HostApplicationIdentity.swift` 与
`Packages/IntatisKnowledge/Sources/KnowledgeHostIdentity.swift`。这些值记录完成时事实，不把 dirty files
转化为已提交 provenance。

在签名/公证或宣称 clean-machine release 前，必须由 Intatis owner 将所需 shared changes 纳入可审计
revision、恢复 clean checkout，并在 Egakium 中重新执行完整 contract/build/test/runtime/license gate。
不得把 Intatis 工作树复制回 Egakium 来规避这个要求。

## 以后升级

1. 先记录 Intatis exact HEAD、status、tracked diff digest 与 untracked inventory；下游不修改它。
2. 核对 `CodexRuntimeHostContract.publicAPIMajorVersion == 1` 和
   `/Users/vita/Vitemis/Intatis/docs/CODEX_RUNTIME_INTEGRATION.md`。
3. 若 runtime version/derivation/kit 改变，单独审查 architecture、manifest、license、SBOM、签名与
   notarization；不能只更新字符串或 hash。
4. 运行 Egakium integration check、完整 Swift tests、CLI selftest、macOS/iOS Xcode builds、App bundle
   runtime/CEF inventory 和身份扫描。
5. 保持 `Package.swift` 与 `project.yml` 只引用同一个 `../../Intatis`；不得增加 snapshot/fallback。
6. 只有 v1 major 或额外 Intatis product 的 source compatibility、产品回归与发行证据都成立，才能
   接受升级。
