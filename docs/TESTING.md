# TESTING

文档状态：当前测试矩阵与最近证据
最近执行：2026-09-12
产品基线：v0.4（build 50）

## 2026-09-12 修复与本机安装

用户在诊断后明确要求修复并安装到本机。已修复三个 `CodexBusinessToolHost` 调用的必填
`imageGenerator` 参数，直接接入已存在的服务：CLI/Code 使用
`ProviderImageGenerationToolService(registry:)`，Cowork 使用 `registryBox.imageToolService()`。
业务改动共五行；没有修改 shared Intatis、测试源码、entitlements、依赖 pin、构建脚本或版本号。

### 修复后的验证

| 检查 | 结果 |
|---|---|
| integration consistency / version consistency / `git diff --check` | PASS |
| `swift test --disable-sandbox --disable-automatic-resolution` | PASS：68 cases，60 passed、8 个真实付费 smoke skipped、0 failed |
| CLI offline selftest | PASS：Chat streaming、Code read/write、Cowork inference profiles |
| 最终 `EgakiumMac` ARM64 Release build | PASS，exit 0，`BUILD SUCCEEDED` |
| App 内 Mach-O inventory | PASS，13 个文件全部为 arm64 |
| 全部嵌套 code 的 Developer ID / Team ID 一致性 | PASS，13 个签名对象，含五个 CEF dylibs、framework、五个 Helpers、Codex、主 App |
| 安装目录的 strict App seal | PASS |
| 安装目录的 canonical Codex `execute` validator | PASS，exact version / derivation / App Server initialize |
| 从 `/Applications/Egakium.app` 启动 | PASS，Cowork 主窗口可见，进程 executable 路径核对一致 |
| 实际 CEF framework 加载 | PASS，运行中进程映射来自安装 App 的 `Contents/Frameworks` |
| 已有旧 Cowork 会话恢复 | 未通过：Canvas preparing、Main inference unavailable；未改写历史或绑定 |
| 真实 provider / Canvas paint E2E / 公证与正式分发 | 未执行，不能从上述通过项外推 |

完整测试在修复后运行两次，均为 68 cases / 0 failed；第二次的三个 suites 分别为
`EgakiumRuntimeIntegrationTests` 5、`EgakiumCanvasTests` 13、`EgakiumCLITests` 50（含 8 skipped）。
之前 CLI 的后续类型推断错误也已消失。

最终构建命令：

```sh
xcodebuild -project Egakium.xcodeproj \
  -scheme EgakiumMac -configuration Release \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath "$EGAKIUM_INSTALL_WORK/DerivedData" \
  -clonedSourcePackagesDirPath "$PWD/build/egakium-cowork-ui-xcode/SourcePackages" \
  -disableAutomaticPackageResolution \
  -onlyUsePackageVersionsFromResolvedFile -skipPackageUpdates \
  -jobs 4 ARCHS=arm64 ONLY_ACTIVE_ARCH=NO \
  COMPILER_INDEX_STORE_ENABLE=NO CODE_SIGNING_ALLOWED=NO build
```

`EGAKIUM_INSTALL_WORK` 指向本轮新建的 `/private/tmp` 工作目录。显式 `ARCHS=arm64` 限定整个依赖图；
只限制 App target 的架构仍可能额外编译 package 的 x86_64 slice。首轮 `-quiet` Release 构建输出过
`failed with exit code 0` 诊断，但最终退出成功；第二次保留完整日志并明确报告 `BUILD SUCCEEDED`。
未依据该文字误判源码错误，未修改依赖来消除 warning。

### CEF 的真实加载补充门

ad-hoc 签名即使通过 `codesign --verify --deep --strict` 和 Codex `execute-local`，也不证明整个 App
可以加载 CEF。本轮实际运行时 `dlopen` 被 Hardened Runtime Library Validation 拒绝，诊断为
`mapping process and mapped file (non-platform) have different Team IDs`。

最终直接调用系统 `codesign` 使用可用 Developer ID Application 身份；没有列出 Keychain 内容、
导出证书/私钥或关闭 library validation。依次签署全部 CEF dylibs、framework、五个 Helpers、Codex，
更新签名后的 Codex manifest/inventory，再签外层 App。所有签名使用 secure timestamp 和现有
entitlements，并从已签名制品核对相同的 Developer ID/Team ID。canonical validator 使用 exact
Developer ID identity 的 `execute` 模式，最后通过运行中进程的 CEF 映射证实实际加载成功。

正式安装完成于 2026-09-12 15:03:38 +08:00，位置 `/Applications/Egakium.app`，版本 0.4/build 50。
原始 App 备份为 `build/egakium-install-backups/20260912-142942-665198/Egakium.app`；本轮中间制品另有
独立备份。替换采用同卷 rename，安装目录再次核对主 executable digest、strict seal 与 Codex execute。
一次 canonical initialize 探针没有返回 result 时已自动回滚；同一制品复验及最终安装目录复验通过。
没有忽略失败、替换 validator、自动上传公证或删除用户会话/配置。

### 仍未通过的边界

- 打开已有旧会话后，历史与 Project sheet 可见，但 Canvas 仍停在 preparing、Main 未 attached、
  Send 不可用。只读检查后关闭 sheet，未保存设置、重绑模型、修改 EventLog 或触发旧任务恢复。
  CEF 加载问题已独立排除，旧会话的 root/inference 恢复仍须进一步定位。
- 当前安装是本机 Developer ID 自建版本，未进行 Apple notarization、staple、正式 Gatekeeper
  分发验收、DMG/ZIP 或 clean-machine 验证；不把“应用已经打开”写成正式发行完成。
- Intatis 在构建期间有外部修改，最终由 owner 提交为 clean
  `ae589e17d90a217e43c55bb05ebb487b05e6b480`。最终验证开始时采集了 552 个 build-source 指纹；其中
  一份 shared Cowork reviewer source 在测试之后、最终 Release 构建完成之前被外部更新。以上结果
  按各自实际执行时点记录，不宣称从该 clean HEAD 独立执行了完整发行回归。

## 2026-09-12 构建与安装复核（修复前）

本次是当前机器的构建/安装排查，没有修改业务源码、测试源码、构建脚本、依赖 pin 或已安装 App。
下文 2026-08-31 的通过结果保留为历史证据，不能用于证明当前 Intatis 工作树仍与 Egakium source
compatible。当前 CLI 和 macOS App 构建均失败。

### 检查环境与依赖状态

- macOS 27.0（26A5425a）、Xcode 27.0（27A5228h）、Apple Swift 6.4、arm64；
- XcodeGen 2.45.4、CMake 4.3.2、Ninja 1.13.2，Xcode first-launch check exit 0；
- Egakium 起始工作树 clean；Intatis HEAD 为 `682c6fc82d3ed6e4db538709df351be60ac0d37a`；
- 根 `Package.resolved`、生成的 Xcode workspace lockfile 与 Intatis lockfile 的九个 pins 一致；
- Intatis 工作树在排查期间发生外部并发修改；仅凭 HEAD 无法复现本次所有检查，未宣称 clean build。

2026-09-12 13:53:46 +08:00 的末次只读采集为 10 个 tracked changes、4 个 untracked files；
tracked diff SHA-256 为
`87f18f1e8f760cf247e73d54512fcc51431696425039be7a62139a51ac4f7bc8`，
sorted untracked path inventory SHA-256 为
`77e3e4f57da0386acf50a156f1e5a97ed602b421a4cab228a5c68536e09beaff`。
这些值只标识采集时的外部工作树；构建开始时没有冻结该依赖，也没有捕获可重建整个时间区间的快照。

### 实际结果

| 检查 | 结果与边界 |
|---|---|
| integration consistency / version consistency | PASS，0.4/build 50 |
| `swift package --disable-sandbox dump-package` | PASS；受当前执行沙箱影响，user cache 写入有 warning |
| `xcodegen generate` | PASS，仅重新生成 ignored Xcode project |
| `swift build --disable-sandbox --disable-automatic-resolution` | FAIL，exit 1；CLI 的 `CodexBusinessToolHost` 调用缺少 `imageGenerator` |
| `EgakiumMac` arm64 Debug build，独立 DerivedData，正常系统权限 | FAIL，exit 65；`CodeViewModel.swift` 同样缺少 `imageGenerator` |
| CEF archive SHA-256 | PASS，与 `config/cef.cmake` 的 exact pin 一致 |
| `scripts/prepare-cef-runtime.sh Debug` | PASS，sandbox ON；增量检查，Ninja 报告 `no work to do` |
| Intatis Codex kit canonical static validation | PASS，exact runtime 0.145.0-intatis.4 |
| 已安装 App 的 Codex canonical static validation | PASS，manifest/inventory/architecture/license closure |
| 已安装 App 的 `codesign --verify --deep --strict` | FAIL，App 没有完整资源签名封装 |
| 已安装 App 的 Gatekeeper execute assessment | FAIL，正常系统权限下也报告同一签名错误 |
| 已安装 App 的 `stapler validate` | FAIL，未附带公证票据 |
| 临时副本完整 ad-hoc 签名、strict seal | PASS；不涉及 Developer ID，未替换安装目录 |
| 临时副本 canonical `execute-local` | PASS，exact version / derivation / App Server initialize |
| build/embed/release shell 语法、两份 entitlements plist | PASS；仅语法/格式检查，不是发行执行 |

本次未运行当前源码的 XCTest suites 或 CLI selftest：CLI 编译尚未完成，旧 binary 的通过结果不能
作为当前源码的验证。未运行 Release build、iOS build、完整 GUI/Canvas/provider E2E、Developer ID
签名、公证上传、DMG/ZIP 打包或 clean-machine 安装；未读取 Keychain/证书/profile 内容。

### 编译阻塞的可复现命令与定位

CLI：

```sh
swift build --disable-sandbox --disable-automatic-resolution
```

首个错误是 `Apps/egakium-cli/Sources/CodexRuntimeCLI.swift:192` 的
`missing argument for parameter 'imageGenerator' in call`。后续 `Dictionary` 泛型推断及字符串表达式
type-check 诊断尚未通过修复后的复验，不应直接视为四个独立根因。

macOS：

```sh
EGAKIUM_AUDIT_DIR="$(mktemp -d /private/tmp/egakium-build-audit.XXXXXX)"
xcodebuild -project Egakium.xcodeproj \
  -scheme EgakiumMac -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath "$EGAKIUM_AUDIT_DIR/DerivedData-Debug" \
  -clonedSourcePackagesDirPath "$PWD/build/egakium-cowork-ui-xcode/SourcePackages" \
  -disableAutomaticPackageResolution \
  -onlyUsePackageVersionsFromResolvedFile -skipPackageUpdates \
  ENABLE_DEBUG_DYLIB=NO CODE_SIGNING_ALLOWED=NO build -quiet
```

该命令复用本机已有 exact package checkouts，未测试从空缓存联网解析。错误在
`Apps/EgakiumMac/Sources/CodeViewModel.swift:932`；另外通过源码核对发现
`CoworkViewModel.swift:1338` 的构造调用也缺少该参数。Intatis `682c6fc` 的 committed diff
已加入必填 `imageGenerator: any ImageGenerationToolService`，其宿主示例已接入现有图片服务。
Egakium 也已有相应服务，后续应修复三处宿主接线并重跑完整回归，保持唯一 Intatis dependency。

最初在受限执行环境中运行 Xcode，失败原因是不能写 SwiftPM manifest diagnostics cache，并伴随
CoreSimulator service 不可访问。授予正常系统构建权限后越过该阶段，才得到上述真实源码错误。
不能把第一次沙箱错误当作项目依赖损坏或本机 Simulator 安装失败。

正常权限的 Xcode 在准备阶段曾长时间无日志但持续占用 CPU。3 秒进程采样显示
`IDESwiftPackageAbstractGroup.synchronizeRecursiveFileSystemContent` 等 package 文件树同步调用；
之后正常进入编译并报告源码错误。本次没有证明死锁，也没有定位到某个目录是唯一耗时根因。

### 安装制品与签名验证

`/Applications/Egakium.app` 为 arm64、0.4/build 50、minimum macOS 26.0。主 executable 与
`build/egakium-cowork-ui-xcode/Build/Products/Debug/EgakiumMac.app` 的 2026-08-31 executable
逐字相同。CEF framework、五个标准 Helpers、Codex runtime 均存在；App/CEF/Helpers 签名信息为
`adhoc,linker-signed`、`Sealed Resources=none`，不是已完成 Developer ID 分发的 App。

```sh
codesign --verify --deep --strict /Applications/Egakium.app
spctl --assess --type execute --verbose=2 /Applications/Egakium.app
xcrun stapler validate /Applications/Egakium.app
```

前两项在可访问系统服务的环境中报告
`code has no resources but signature indicates they must be present`；最后一项报告
`does not have a ticket stapled to it`。这证明签名/发行验收失败，不等于已复现完整 GUI 的每一种启动故障。

为隔离制品损坏与签名步骤缺失，只复制已安装 App 到本轮 `/private/tmp` 诊断目录，再按现有
`package-macos-release.sh` 的依赖顺序签名 CEF 所有 dylibs、framework、五个 Helpers 和 Codex，
重建 Codex manifest/inventory 后签名外层 App。诊断使用 ad-hoc identity、原有 Hardened Runtime /
entitlements；未修改业务资源或降低 CEF sandbox。完整 App strict seal 与 canonical
`validate-codex-runtime.sh <temporary-app>/Contents/Resources/CodexRuntime/arm64 arm64 - execute-local`
通过。此副本是旧 Debug binary 的诊断制品，不是新源码构建成功或正式安装包的证明。

### 安装入口的实际含义

- `make app` 只生成并打开 Xcode project，不构建或安装 macOS App；
- `make build` / `make release` 构建 SwiftPM CLI；
- `make install` 把 `.build/release/egakium` 链接到 `BINDIR`，不会安装 `.app` 或完整 runtime bundle；
- 正式 `.app`/DMG/ZIP 仍由 `scripts/package-macos-release.sh` 完成签名、公证与分发验收。

本机检查的 `/usr/local/bin`、`/opt/homebrew/bin` 和用户 `.local/bin` 均没有 `egakium` 入口；
这不影响 Finder 中 App 是否存在。排查任务未执行 CLI/App 安装或覆盖现有文件。

## 目标

本矩阵验证 Egakium 已从复制 snapshot 切换为单一 Intatis checkout，并直接消费 presentation-only
`IntatisCoworkUI`，同时保持产品身份、macOS Cowork/Canvas、iOS Chat-only 和发行 bundle 边界。测试不能只证明旧源码退出 manifest；还要证明删除后
SwiftPM、CLI、macOS/iOS App 与 exact runtime/CEF closure 都能完成。

## 前置事实

- Egakium root：`/Users/vita/Vitemis/Volans/Egakium`
- Intatis root：`/Users/vita/Vitemis/Intatis`
- dependency：`.package(path: "../../Intatis")`
- Intatis Codex host API：v1
- Intatis Cowork UI API：v1
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
- macOS product graph、source adapter 与 public contract tests直接引用 `IntatisCoworkUI`；
- 三个 host 入口安装 Egakium HostIdentity；
- Code/Cowork production source 使用 `CodexAppServerSession`/`codexRuntimeREPL`；
- snapshot marker 与旧 Egakium shared imports 不存在；
- macOS visible nav 仍只有 Cowork；
- CEF init、Canvas composition 与右侧 `IntatisCoworkContentView` 仍存在；
- Egakium 本地 Cowork inference composition 与 `ComposerAttachmentSurfaces.swift` 副本不存在；
- `EgakiumiOS` target section 不含 `IntatisCoworkUI`；
- product UI 中没有用户可见 Intatis 品牌 literal。

## SwiftPM build/test

```sh
swift build --disable-sandbox --disable-automatic-resolution
swift test --disable-sandbox --disable-automatic-resolution
```

2026-08-31 Cowork UI 接入后结果：

| Suite | Result |
|---|---:|
| `EgakiumRuntimeIntegrationTests` | 5 passed |
| `EgakiumCanvasTests` | 13 passed |
| `EgakiumCLITests` | 50 executed, 42 passed, 8 skipped |
| Total | 68 cases: 60 passed, 8 explicitly skipped, 0 failed |

8 个 skipped tests 都受显式环境变量保护，可能产生真实 provider/embedding/reranker/permission-review
请求和费用；默认离线矩阵不运行它们。它们不是编译失败或意外 skip。

### Public runtime contract tests

`Tests/EgakiumRuntimeIntegrationTests/EgakiumRuntimeIntegrationTests.swift` 只使用 public imports，并验证：

- `CodexRuntimeHostContract.publicAPIMajorVersion == 1`；
- pinned runtime version/identity 可读取；
- Egakium 可以只用 public types 构造 isolated minimal configuration；
- HostIdentity 保留 Egakium config/storage/environment/defaults/sidecar namespace。
- `IntatisCoworkUIContract.publicAPIMajorVersion == 1`，且完整右侧 public state/actions/thread/view types 可由
  消费项目直接 import。
- Canvas自动刷新只由 successful completed App Server `fileChange` event驱动；same-workspace child可
  触发，failed/different-workspace被抑制，host保留manual revision且源码不含polling/watcher。

不得为让 test 编译而增加 `@testable import Intatis*` 或读取 Intatis internal source。

### Canvas tests

13 个 tests 覆盖：

- source-owned template 与无 injected runtime；
- concurrent/no-overwrite Session initialization；
- `@main` edits preservation；
- Session path isolation；
- generic identity-free child template；
- fresh element provisioning 不修改 shared index；
- unsafe Session/Element IDs fail closed；
- symlink rejection；
- rollback 只删除仍为原模板的目录。
- automatic reload policy：root/same-workspace child success、failure/non-file/different-or-unknown workspace
  suppression。

## CLI offline smoke

```sh
.build/debug/egakium selftest
```

2026-08-31 重跑结果：PASS。

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
  -derivedDataPath build/egakium-cowork-ui-xcode \
  ENABLE_DEBUG_DYLIB=NO \
  CODE_SIGNING_ALLOWED=NO \
  build -quiet
```

2026-08-31 结果：PASS（unsigned Debug）。产物：

```text
build/egakium-cowork-ui-xcode/Build/Products/Debug/EgakiumMac.app
```

确认的 Info.plist facts：

- display/name/product：Egakium；
- executable：`EgakiumMac`；
- bundle identifier：`com.Vita0818.EgakiumMac`；
- version/build：`0.4` / `50`；
- architecture：arm64。

编译有来自当前 source/Intatis 的非阻塞 Swift deprecation/no-usage warnings；无 build error。
`ENABLE_DEBUG_DYLIB=NO` 的主 executable binary scan可见 `IntatisCoworkUI`/
`IntatisCoworkContentView` symbol strings，证明不是只在 manifest 声明未链接。

## Built App Codex Runtime gate

```sh
scripts/validate-codex-runtime.sh \
  '/Users/vita/Vitemis/Volans/Egakium/build/egakium-cowork-ui-xcode/Build/Products/Debug/EgakiumMac.app/Contents/Resources/CodexRuntime/arm64' \
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
  -derivedDataPath build/egakium-cowork-ui-ios \
  CODE_SIGNING_ALLOWED=NO \
  build -quiet
```

2026-08-31 结果：PASS。产物是 x86_64 + arm64 simulator universal binary。

额外验证：

- `project.yml` 的 iOS dependencies 只有七个 Chat subset products；
- final main/debug-dylib scan未发现 `IntatisCodexRuntime`、`IntatisAgentKernel`、`IntatisCowork`、`IntatisCoworkUI`、
  `IntatisTools`、`IntatisPermission` 或 CEF；
- final app 没有 Codex executable/framework/CEF；
- `ThirdPartyNotices/OpenAICodexRuntime.md` 只是完整 attribution resource，不代表 runtime linkage。

## UI/source invariant gate

静态必须保持：

- `EgakiumMacRootView.visibleNavigationItems == [.cowork]`；
- Chat/Code cases、views 与 runtime branches仍存在；
- `CoworkSessionView` 使用一个 `HSplitView` + 一个 Egakium-owned `CoworkViewModel`；
- 左侧 `CoworkCanvasHost`、右侧 `IntatisCoworkContentView`；
- 右侧只接收 `IntatisCoworkContentState/Actions/ThreadSource` 与 host settings slot，不拥有 runtime/session/
  provider/workspace/MCP/permission/dynamic tools；
- product adapter 不直接调用 `CoworkShell`，本地 Cowork inference/Goal editor/attachment UI 副本不存在；
- `CoworkCanvasHost` 只使用 `EgakiumCEFView`；
- `CoworkViewModel.canvasReloadRevision` 只从 completed/successful root或same-workspace-child
  `fileChange`增长，并与manual revision共同驱动现有 CEF reload；
- `CoworkCanvasHost`/`CoworkViewModel` 不含 DispatchSource、Timer或metadata polling watcher；
- 不存在独立 Canvas WindowGroup/Open Canvas action/WKWebView fallback；
- exact `@main`/native child Canvas assignment paths由产品 host 注入。

本轮还实际启动了 built Debug App，并通过 macOS accessibility tree + screenshot 确认：只有一个
Egakium window；sidebar 可见模式只有 Cowork；Recent/New Cowork Session/Settings、深色产品样式和
Egakium 品牌正常；没有独立 Canvas window。当前本机无 Cowork Session，进入真实左右 split 需要在
系统文件选择器中授予 workspace 并写 security-scoped bookmark，本轮未擅自执行。因此完整 Session
内左 CEF/右 harness 与 Canvas interaction 仍由 source/build/bundle gate 覆盖，尚未作为手工 E2E 通过。
自动刷新本轮已通过纯 policy行为测试、source contract gate和 shipping-shaped App build；尚未用真实
App Server/provider产生 `fileChange` 并观察 CEF画面自动更新，因此 event-to-paint仍属于上述完整 E2E
缺口。manual CEF reload的既有 bridge继续由 build/runtime smoke覆盖。

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
