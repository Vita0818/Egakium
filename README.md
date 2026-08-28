# Egakium

当前版本：**v0.4**（build 50）
状态：pre-1.0；本地源码、Debug App 和 exact runtime 组装已验证，Developer ID 正式签名、公证与发行
验收尚未执行。

Egakium 是 Apple-first 的本地 AI 工作区。macOS 当前以 Cowork-first 单窗口呈现：左侧是 CEF Session
Canvas，右侧是完整 Cowork harness。Chat 与 Code 产品面仍编译保留，只在主 sidebar 隐藏；iOS 是严格
Chat 子集；CLI 提供 headless Chat/Code/Cowork 与 MCP 管理。

## 共享 Intatis Runtime

2026-08-28 起，Egakium 不再维护共享 runtime 的源码快照。根 `Package.swift` 与 `project.yml` 都通过
`../../Intatis` 直接消费唯一 checkout：

```text
/Users/vita/Vitemis/Intatis
```

共享 Core、Protocol、Providers、Conversation、Artifacts、SharedUI、Tools、Knowledge、Skills、Permission、
MCP、AgentKernel、Cowork 与 `IntatisCodexRuntime` 都从该 checkout 编译。Egakium 仓库只保留产品 host、
UI、配置/身份接线、Canvas/CEF 和 CLI 表面；没有复制 package、runtime facade、第二 backend 或旧
AgentLoop fallback。

macOS 和 CLI 的 Code/Cowork 使用官方 `CodexAppServerSession`；项目工具通过
`CodexRuntimeDynamicTools` 接入。macOS build 会验证 Intatis runtime kit，并把 exact arm64 Codex
executable、manifest 与 license closure 嵌入自己的 sealed App bundle。完整迁移事实与升级规则见
[`docs/INTATIS_RUNTIME_INTEGRATION.md`](docs/INTATIS_RUNTIME_INTEGRATION.md)。

## 产品身份与数据

三个进程入口在构造共享对象前只安装一次：

```swift
IntatisHostApplication.configure(name: "Egakium")
```

共享实现因此继续使用 Egakium 自己的 `EGAKIUM_*` 环境变量、`egakium.*` defaults、
`com.vitemis.egakium.*` Keychain service、`.egakium/` workspace/session state 与 Egakium permission
sidecar。Intatis 模块名是共享实现名称，不会变成产品品牌或用户数据命名空间。

2026-08-18 完成的 Egakium identity hard cutover 仍有效：应用不探测或导入更早 identity 的会话、配置、
凭据或缓存，旧数据不自动删除但不可见。

## 当前产品面

### macOS

- 唯一 shipping target：`EgakiumMac`，Developer ID + notarization + 直接下载；
- 可见导航：Cowork 与 Settings；Chat/Code 仅 presentation-hidden；
- Cowork：一个 `CoworkViewModel`/Session，左 CEF Canvas、右既有 composer/transcript/Agents/Goal/Tasks；
- Code/Cowork：Codex App Server、dynamic tools、workspace confinement、permission chain、Skills、MCP、
  Knowledge、文档/媒体和 managed execution；
- Canvas renderer：pinned official CEF
  `151.3.17+gf059e67+chromium-151.0.7922.138` ARM64，五个 standard sandbox Helpers，无 WebKit fallback。

源码中的 `EgakiumMacAppStore` 是 legacy target，不属于产品、默认构建矩阵或 release gate。

### iOS

iOS 只链接 Intatis 的 Core、Protocol、Providers、Conversation、Artifacts、Multimodal 和 SharedUI。
它不链接 Tools、Knowledge、Skills、Permission、MCP、AgentKernel、Cowork、Codex Runtime、EgakiumCanvas
或 CEF；这是一条 target-level 边界，不是运行时 feature flag。

### CLI

`egakium` 保留 Chat/Code/Cowork REPL、MCP 管理、诊断和离线 self-test。Code/Cowork 使用同一
`IntatisCodexRuntime`；开发时可用 `EGAKIUM_CODEX_RUNTIME` 指定 executable，但 exact version/
derivation 不匹配会 fail closed。

## 仓库结构

```text
Apps/
  EgakiumMac/          macOS host、UI、CEF bridge/resources
  EgakiumiOS/          iOS Chat-only host
  egakium-cli/         CLI host 与产品测试
Product/
  EgakiumCanvas/       产品专属 Canvas store/template/Skill/tests
Tests/
  EgakiumRuntimeIntegrationTests/  只用 public imports 的 v1 contract tests
docs/                   当前规范、迁移报告与历史记录
scripts/                Intatis/CEF 验证、构建、发行与诊断入口
ThirdPartyNotices/      Egakium 独有 CEF/JCEF/Skill 声明
OpenSource/             26 个研究 checkout gitlink，不进入产品依赖图
Package.swift           Egakium overlay + 唯一 ../../Intatis dependency
project.yml             XcodeGen 产品图与 bundle phases
```

`Packages/`、`Vendor/` 与 `ThirdPartyStandards/` 的 tracked shared snapshot 已删除。目录下若仍有本地
ignored cache，不是产品 source，也不得为了清理外观而误删。

## 开发与验证

需要 Xcode 27 / Swift 6.x、XcodeGen、唯一 Intatis checkout，以及已准备的 pinned CEF/Intatis runtime
assets。

```sh
scripts/check-egakium-intatis-integration.sh
scripts/check-version-consistency.sh
swift package --disable-sandbox dump-package
swift test --disable-sandbox --disable-automatic-resolution
.build/debug/egakium selftest
xcodegen generate

xcodebuild -project Egakium.xcodeproj -scheme EgakiumMac \
  -configuration Debug -destination 'platform=macOS,arch=arm64' \
  CODE_SIGNING_ALLOWED=NO build

xcodebuild -project Egakium.xcodeproj -scheme EgakiumiOS \
  -configuration Debug -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
```

XcodeGen 后置脚本会把根 `Package.resolved` 同步到 workspace，确保命令行和 Xcode 解析同一个 local
Intatis package graph。当前详细测试证据和未执行 gate 见 [`docs/TESTING.md`](docs/TESTING.md)。

## macOS 直接分发

正式发行仍使用：

```sh
EGAKIUM_NOTARY_PROFILE=<profile-name> scripts/package-macos-release.sh
```

release 必须在 clean、可审计的 Intatis revision 上重新构建，并验证 exact Codex Runtime、CEF
framework/Helpers、第三方 notices、Developer ID signatures、notarization、staple、Gatekeeper 和最终
ZIP/DMG hashes。当前 sibling Intatis checkout 是 dirty 开发状态，因此本次 Debug 验证不能作为可重现
release 证据。

## 文档入口

- [`docs/README.md`](docs/README.md)：当前文档索引；
- [`docs/INTATIS_RUNTIME_INTEGRATION.md`](docs/INTATIS_RUNTIME_INTEGRATION.md)：本次直接接入报告；
- [`docs/EGAKIUM_CANVAS_COWORK.md`](docs/EGAKIUM_CANVAS_COWORK.md)：Canvas/Cowork 产品合同；
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)：运行时、安全与持久化语义；
- [`docs/DO_NOT_BREAK.md`](docs/DO_NOT_BREAK.md)：回归禁区；
- [`docs/MACOS_DISTRIBUTION.md`](docs/MACOS_DISTRIBUTION.md)：Developer ID 发行合同；
- [`docs/VERSIONING.md`](docs/VERSIONING.md)：版本治理。
