# TESTING

文档状态：当前测试矩阵与最近证据
最近执行：2026-08-28
产品基线：v0.4（build 50）

## 目标

本矩阵验证 Egakium 已从复制 snapshot 切换为单一 Intatis checkout，同时保持产品身份、macOS
Cowork/Canvas、iOS Chat-only 和发行 bundle 边界。测试不能只证明旧源码退出 manifest；还要证明删除后
SwiftPM、CLI、macOS/iOS App 与 exact runtime/CEF closure 都能完成。

## 前置事实

- Egakium root：`/Users/vita/Vitemis/Volans/Egakium`
- Intatis root：`/Users/vita/Vitemis/Intatis`
- dependency：`.package(path: "../../Intatis")`
- Intatis Codex host API：v1
- exact executable：`codex-cli 0.145.0-intatis.4`
- macOS architecture：arm64
- CEF：`151.3.17+gf059e67+chromium-151.0.7922.138`

本轮 Intatis checkout 为 dirty external state；结果对应当时 current files。正式 release 需要 clean、可审计
revision 上重跑全部 gate。

## 必跑静态/依赖 gate

```sh
pwd
git rev-parse --show-toplevel
git status --short

scripts/check-egakium-intatis-integration.sh
scripts/check-version-consistency.sh
swift package --disable-sandbox dump-package
```

`check-egakium-intatis-integration.sh` 至少验证：

- `../../Intatis` 精确解析到 canonical root；
- Package/XcodeGen 都引用 Intatis 与 `IntatisCodexRuntime`；
- 三个 host 入口安装 Egakium HostIdentity；
- Code/Cowork production source 使用 `CodexAppServerSession`/`codexRuntimeREPL`；
- snapshot marker 与旧 Egakium shared imports 不存在；
- macOS visible nav 仍只有 Cowork；
- CEF init 和 Canvas composition 仍存在；
- product UI 中没有用户可见 Intatis 品牌 literal。

## SwiftPM build/test

```sh
swift build --disable-sandbox --disable-automatic-resolution
swift test --disable-sandbox --disable-automatic-resolution
```

2026-08-28 删除 snapshot 后结果：

| Suite | Result |
|---|---:|
| `EgakiumRuntimeIntegrationTests` | 3 passed |
| `EgakiumCanvasTests` | 12 passed |
| `EgakiumCLITests` | 50 executed, 42 passed, 8 skipped |
| Total | 65 cases: 57 passed, 8 explicitly skipped, 0 failed |

8 个 skipped tests 都受显式环境变量保护，可能产生真实 provider/embedding/reranker/permission-review
请求和费用；默认离线矩阵不运行它们。它们不是编译失败或意外 skip。

### Public runtime contract tests

`Tests/EgakiumRuntimeIntegrationTests/EgakiumRuntimeIntegrationTests.swift` 只使用 public imports，并验证：

- `CodexRuntimeHostContract.publicAPIMajorVersion == 1`；
- pinned runtime version/identity 可读取；
- Egakium 可以只用 public types 构造 isolated minimal configuration；
- HostIdentity 保留 Egakium config/storage/environment/defaults/sidecar namespace。

不得为让 test 编译而增加 `@testable import Intatis*` 或读取 Intatis internal source。

### Canvas tests

12 个 tests 覆盖：

- source-owned template 与无 injected runtime；
- concurrent/no-overwrite Session initialization；
- `@main` edits preservation；
- Session path isolation；
- generic identity-free child template；
- fresh element provisioning 不修改 shared index；
- unsafe Session/Element IDs fail closed；
- symlink rejection；
- rollback 只删除仍为原模板的目录。

## CLI offline smoke

```sh
.build/debug/egakium selftest
```

2026-08-28 结果：PASS。

- Chat streaming reply；
- Code write/read tool execution 与 approval；
- Cowork exact inference profile/config resolution；
- 不需要 API key 或网络。

这条 self-test 使用测试 provider 验证共享 business runtime，不启动真实 Codex executable。真实
`codexRuntimeREPL` 仍由 Xcode/App bundle 和可选真实-provider smoke 覆盖。

## Xcode generation

```sh
xcodegen generate
```

结果：PASS。后置脚本同时生成 scheme visibility preferences，并把根 `Package.resolved` 同步到 workspace。

## macOS App build

```sh
xcodebuild -project Egakium.xcodeproj \
  -scheme EgakiumMac \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath build/egakium-intatis-xcode \
  CODE_SIGNING_ALLOWED=NO \
  build -quiet
```

结果：PASS（unsigned Debug）。产物：

```text
build/egakium-intatis-xcode/Build/Products/Debug/EgakiumMac.app
```

确认的 Info.plist facts：

- display/name/product：Egakium；
- executable：`EgakiumMac`；
- bundle identifier：`com.Vita0818.EgakiumMac`；
- version/build：`0.4` / `50`；
- architecture：arm64。

编译有来自当前 source/Intatis 的非阻塞 Swift deprecation/no-usage warnings；无 build error。

## Built App Codex Runtime gate

```sh
scripts/validate-codex-runtime.sh \
  '/Users/vita/Vitemis/Volans/Egakium/build/egakium-intatis-xcode/Build/Products/Debug/EgakiumMac.app/Contents/Resources/CodexRuntime/arm64' \
  arm64 - static
```

结果：PASS。closure files：

- `codex`
- `runtime-manifest.json`
- `SHA256SUMS.txt`
- `ThirdPartyNotices/runtime.spdx.json`
- `ThirdPartyNotices/LICENSES.txt`

关键 hash：

| File | SHA-256 |
|---|---|
| `codex` | `9d5d81ef622f5bf7bc288837f2cd825fdd686dfe770109a0e9218cd087c90c74` |
| manifest | `881b12b23138f5fedc1e515a5afa53c0b6072ce133474b1ed252e4189a44cf3b` |
| sums | `ed4d0fc7193d38d518bcc9bdcd043381b27312aaebe43e0fb0bfce1aa2704e08` |

App executable 与 Codex executable 都由 `file` 确认为 arm64 Mach-O。

### Release signing flow simulation

为验证新增的 release gate，在 `/private/tmp` 的 Debug App 副本上执行了等价 ad-hoc 流程：内向外重签
CEF libraries/framework/five Helpers 与 Codex executable，更新 Codex `binary_sha256`/inventory，签外层
App，运行 `codesign --verify --deep --strict`，再以 `execute-local` 启动 exact version/derivation 与 App
Server initialize smoke。结果：PASS。临时 App 副本验证后已删除；原 build product 未修改。

这证明脚本顺序与签名后 integrity 模型可工作，但不等于 Developer ID timestamp、Apple notarization 或
Gatekeeper 已执行。

## Built App CEF gate

macOS App inventory 必须包含：

- `Chromium Embedded Framework.framework`；
- `EgakiumMac Helper.app`；
- `EgakiumMac Helper (GPU).app`；
- `EgakiumMac Helper (Renderer).app`；
- `EgakiumMac Helper (Plugin).app`；
- `EgakiumMac Helper (Alerts).app`；
- official CEF LICENSE/CREDITS resources。

2026-08-28 inventory：PASS。不得把 framework 单独存在误当成五 Helper/签名 closure 已通过。

## iOS Chat-only build

```sh
xcodebuild -project Egakium.xcodeproj \
  -scheme EgakiumiOS \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build/egakium-intatis-ios \
  CODE_SIGNING_ALLOWED=NO \
  build -quiet
```

结果：PASS。产物是 x86_64 + arm64 simulator universal binary。

额外验证：

- `project.yml` 的 iOS dependencies 只有七个 Chat subset products；
- final debug dylib symbol scan未发现 `IntatisCodexRuntime`、`IntatisAgentKernel`、`IntatisCowork`、
  `IntatisTools`、`IntatisPermission` 或 CEF；
- final app 没有 Codex executable/framework/CEF；
- `ThirdPartyNotices/OpenAICodexRuntime.md` 只是完整 attribution resource，不代表 runtime linkage。

## UI/source invariant gate

静态必须保持：

- `EgakiumMacRootView.visibleNavigationItems == [.cowork]`；
- Chat/Code cases、views 与 runtime branches仍存在；
- `CoworkSessionView` 使用一个 `HSplitView` + 一个 `CoworkViewModel`；
- 左侧 `CoworkCanvasHost`、右侧原 Cowork harness；
- `CoworkCanvasHost` 只使用 `EgakiumCEFView`；
- 不存在独立 Canvas WindowGroup/Open Canvas action/WKWebView fallback；
- exact `@main`/native child Canvas assignment paths由产品 host 注入。

本轮还实际启动了 built Debug App，并通过 macOS accessibility tree + screenshot 确认：只有一个
Egakium window；sidebar 可见模式只有 Cowork；Recent/New Cowork Session/Settings、深色产品样式和
Egakium 品牌正常；没有独立 Canvas window。当前本机无 Cowork Session，进入真实左右 split 需要在
系统文件选择器中授予 workspace 并写 security-scoped bookmark，本轮未擅自执行。因此完整 Session
内左 CEF/右 harness 与 Canvas interaction 仍由 source/build/bundle gate 覆盖，尚未作为手工 E2E 通过。

## Release-only gates（本轮未运行）

- clean/committed Intatis revision 与 clean-machine dependency resolution；
- Developer ID signing，含 CEF dylibs/framework/five Helpers/Codex executable；
- Hardened Runtime/entitlements inspection；
- App notarization、staple、strict codesign、Gatekeeper；
- signed/notarized DMG、ZIP 与 SHA-256 inventory；
- release license/SBOM closure；
- fresh machine launch without sibling checkout/PATH/Homebrew；
- real provider Code/Cowork send/stream/approval/interrupt/shutdown；
- full workspace-backed Cowork UI/Canvas interaction regression（startup/Cowork-only single-window smoke 已过）；
- network/proxy failure and runtime corruption negative tests。

任一 gate 未完成时，只能声称 local Debug integration verified，不能声称 release completed。

## Intatis read-only evidence

每次集成/升级前后记录：

```sh
git -C /Users/vita/Vitemis/Intatis rev-parse HEAD
git -C /Users/vita/Vitemis/Intatis status --porcelain=v1 --untracked-files=all
git -C /Users/vita/Vitemis/Intatis diff --binary HEAD | shasum -a 256
git -C /Users/vita/Vitemis/Intatis ls-files --others --exclude-standard | shasum -a 256
```

本轮 Egakium 没有修改 Intatis；但 external dirty state 在迁移期间变化，因此最终报告必须重新捕获
current evidence，不能把早先摘要冒充最终状态。
