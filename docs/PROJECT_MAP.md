# PROJECT_MAP

文档状态：当前仓库/依赖地图
最近核对：2026-08-31
Git root：`/Users/vita/Vitemis/Volans/Egakium`
产品基线：v0.4（build 50）

## 顶层边界

```text
Egakium repository
├── Apps/                         product hosts and UI
│   ├── EgakiumMac/
│   ├── EgakiumiOS/
│   ├── egakium-cli/
│   └── SharedResources/
├── Product/EgakiumCanvas/        only local Swift library
├── Tests/EgakiumRuntimeIntegrationTests/
├── scripts/                      integration, CEF, runtime, release gates
├── config/cef.cmake              exact official CEF pin
├── ThirdPartyNotices/            Egakium-only CEF/JCEF/Skill notices
├── docs/                         current specs and historical evidence
├── OpenSource/                   26 mode-160000 research gitlinks
├── Package.swift                 overlay + ../../Intatis local package
├── Package.resolved              shared resolution for SwiftPM/Xcode
└── project.yml                   XcodeGen product graph

Sibling first-party dependency
└── /Users/vita/Vitemis/Intatis
    ├── Packages/Intatis*
    ├── Packages/IntatisCodexRuntime
    ├── Packages/IntatisCoworkUI
    ├── .intatis/runtime-kit/0.66/CodexRuntime/
    └── ThirdPartyNotices/
```

`Packages/`、`Vendor/`、`ThirdPartyStandards/` 与旧 tracked MCP parity/conformance snapshot 已退出
Egakium repository/build graph。ignored cache 可能让物理目录仍存在；它们不是 source，不得误报为
tracked snapshot，也不得未经授权清除。

## Build facts

### `Package.swift`

产品：

| Product | Target | Ownership |
|---|---|---|
| `EgakiumCanvas` | `Product/EgakiumCanvas/Sources` | Egakium product layer |
| `egakium` | `Apps/egakium-cli/Sources` | Egakium CLI host |

测试：

| Target | Scope |
|---|---|
| `EgakiumCanvasTests` | Session/element file safety, idempotence, template contract |
| `EgakiumRuntimeIntegrationTests` | `IntatisCodexRuntime` + `IntatisCoworkUI` v1 public imports/identity/minimal configuration |
| `EgakiumCLITests` | product config, attachments, MCP host, diagnostics, real-smoke gates |

package dependency 只有 `.package(path: "../../Intatis")`。CLI 直接依赖完整产品所需 Intatis products；
contract tests 只依赖 v1 最小 `IntatisCore/Protocol/Providers/CodexRuntime/CoworkUI`。

### `project.yml`

packages：

- `Egakium: .`，只提供 `EgakiumCanvas`；
- `Intatis: ../../Intatis`，提供 shared modules/runtime。

`EgakiumMac` target：

- sources：`Apps/EgakiumMac/Sources`、resources、shared resources、icons；
- packages：`EgakiumCanvas` + Intatis complete macOS product set，包含 presentation-only
  `IntatisCoworkUI`；
- CEF：ARM64 bridge/static archives + prepare/embed phases；
- Codex：`Embed Exact Intatis Codex Runtime` post-build phase；
- distribution profile：Developer ID entitlements。

`EgakiumiOS` target 只依赖 Intatis 的七个 Chat subset products。`EgakiumMacAppStore` 是 legacy source
target，不是默认产品或 release gate。

`scripts/hide-xcode-package-schemes.sh` 隐藏 package schemes，并把根 `Package.resolved` 复制到生成的
`Egakium.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`。

## Product entry points

| Surface | Entry | Shared runtime |
|---|---|---|
| macOS | `Apps/EgakiumMac/Sources/EgakiumMacApp.swift` | Intatis shared products + Codex Runtime |
| iOS | `Apps/EgakiumiOS/Sources/EgakiumiOSApp.swift` | Intatis Chat subset only |
| CLI | `Apps/egakium-cli/Sources/EgakiumCLI.swift` | Intatis shared products + Codex Runtime |

三个入口都先安装 `IntatisHostApplication.configure(name: "Egakium")`，再创建 storage/provider/runtime。

## macOS source map

### App composition

- `EgakiumMacApp.swift`：App delegate、CEF init/shutdown、environment、Chat/Code views；Cowork 只保留单窗口
  `HSplitView`、左侧 Canvas 与右侧 `IntatisCoworkContentView` state/action adapter。
- `EgakiumMacRootView.swift`：sidebar/history/settings；visible navigation 仅 `.cowork`，Chat/Code branches
  保留。
- `EgakiumDesign.swift`：Egakium system-native theme/typography mapping。
- `SessionRuntimeManager.swift`：App session runtime lifecycle、removal/status/rename notifications。

### Chat

- `EgakiumChatScreen.swift`
- `AppConfig.swift`
- `AppInferenceCatalog.swift`
- `IntatisSharedUI/ComposerAttachmentSurfaces.swift`（sibling dependency；Chat/Code/Cowork 共用，Egakium
  不再维护本地副本）

共享 `ChatLoop`、provider/catalog/history/renderer 来自 Intatis；产品字符串、selection 与 host storage 仍由
Egakium identity 驱动。

### Code/Cowork Codex hosts

- `CodeViewModel.swift`：`CodexAppServerSession` code lifecycle、events、approval、interrupt、dynamic tools。
- `CoworkViewModel.swift`：native Codex root/child lifecycle、Cowork projection、Canvas initialization/assignment、
  dynamic tools、permissions 与 shutdown。
- `EgakiumCodexRuntimeOverride.swift`：development executable override；shipping App 始终使用 sealed resource。
- `CoworkProjectSettings.swift`：host-owned product/settings content slot；
- `CoworkAgentConversationFixtureView.swift`：独立 shared-shell renderer fixture，不是 product Cowork 右侧
  composition。

完整产品右侧 thread/composer/model/permission/Agents/Goal/Tasks/Inspector/retry presentation 由
`IntatisCoworkUI.IntatisCoworkContentView` 直接提供。它只消费 Egakium host supplied state、bindings、
actions 与 thread source，不拥有 runtime/session/provider/workspace/MCP/permission/dynamic tools。

`CodeViewModel`/`CoworkViewModel` 是 host/UI glue，不实现第二 agent loop 或 protocol translation。

### MCP/Knowledge/product tools

- `MCPProductIntegration.swift`
- `MCPConversationRuntimeHost.swift`
- `MCPAppSessionSurfaces.swift`
- `MCPProjectSettingsSurfaces.swift`
- `KnowledgeAccess.swift`

这些文件把 Egakium UI/settings/session intent 接入 shared Intatis services；模型工具通过 Intatis 官方
dynamic-tool host 暴露，permission/workspace/durable semantics 不在 Egakium 重新实现。

### Diagnostics

- `EgakiumDiagnosticExportService.swift`
- `EgakiumProcessDiagnostics.swift`
- CLI `HangDiagnosticsCommand.swift`

## Canvas/CEF map

### Product Canvas

- `Product/EgakiumCanvas/Sources/SessionCanvasStore.swift`：validated Session/Element IDs、safe path、
  no-overwrite creation、existing lookup、rollback safety。
- `SessionCanvasElementTemplate.swift`：唯一 generic identity-free child HTML seed。
- `EgakiumCanvasSkillRoot.swift`：`Bundle.module` Skill root。
- `Resources/BundledSkills/egakium-canvas-cowork/SKILL.md`：exact `@main`/child editing discipline。
- `Tests/SessionCanvasStoreTests.swift`：13 个 filesystem/template/automatic-reload-policy contract tests。
- `Product/EgakiumCanvas/Sources/CanvasAutomaticReloadPolicy.swift`：纯 fail-closed root/descendant
  file-change/workspace policy，不观察 filesystem。

### macOS renderer

- `Apps/EgakiumMac/Sources/CoworkCanvasHost.swift`：SwiftUI/AppKit wrapper，只创建 `EgakiumCEFView`；组合
  App Server automatic revision与manual revision并驱动现有 CEF reload。
- `Apps/EgakiumMac/Sources/CoworkViewModel.swift`：successful completed root/same-workspace-child
  `fileChange` event筛选与 Session-scoped `canvasReloadRevision` publication；不观察 filesystem。
- `Apps/EgakiumMac/CEF/EgakiumCEFBridge.{h,mm}`：CEF init/shutdown、external pump、request context、child
  browser、strict Session-rooted scheme。
- `EgakiumCEFHelperMain.cc`、`EgakiumCEFScheme.h`、`CMakeLists.txt`：Helpers/scheme/wrapper/host build。
- `config/cef.cmake`：exact CEF archive/version/hash。
- `scripts/prepare-cef-runtime.sh`、`embed-cef-runtime.sh`：build/product closure。

不存在 WKWebView/WebKit renderer、DOM injection backend、renderer adapter 或 fallback。

## Runtime and integration scripts

| Script | Purpose |
|---|---|
| `check-egakium-intatis-integration.sh` | exact sibling path, product imports, HostIdentity, no snapshot/fallback, UI/CEF anchors |
| `validate-codex-runtime.sh` | delegates to Intatis canonical executable validator |
| `validate-runtime-kit.sh` | delegates to Intatis canonical kit validator |
| `embed-intatis-codex-runtime.sh` | validate-copy-revalidate exact arm64 kit into App |
| `hide-xcode-package-schemes.sh` | scheme visibility + workspace lockfile synchronization |
| `prepare-cef-runtime.sh` | verify/build pinned official CEF host closure |
| `embed-cef-runtime.sh` | bundle framework/resources/five Helpers/notices |
| `package-macos-release.sh` | Developer ID/notarization/staple/Gatekeeper/direct-download artifacts |
| `check-version-consistency.sh` | v0.4/build 50 identity/version gates |

## Third-party and research boundaries

- Egakium-owned `ThirdPartyNotices/` only carries CEF/JCEF and project Skill attribution.
- Complete shared Intatis dependency notices are read/bundled directly from sibling
  `/Users/vita/Vitemis/Intatis/ThirdPartyNotices`.
- `OpenSource/` remains 26 shallow upstream gitlinks. It is research provenance, not SwiftPM/Xcode dependency.
- `Chromium/`, `.deps/` and `build/` pre-existed and are not globally owned by this migration. Only exact configured
  CEF/runtime build subpaths participate in product assembly.
- `docs/egakium-cef-baseline/` is read-only history.

## Authority when documents conflict

Current source and configuration win in this order:

1. `Package.swift` / `project.yml` / current source;
2. `INTATIS_RUNTIME_INTEGRATION.md` and `CURRENT_STATE.md`;
3. active architecture/contracts;
4. dated/historical reports.

Old paths such as `Packages/EgakiumCowork/Sources/Orchestrator.swift` now refer only to migration history. The
corresponding shared implementation, when still used, lives in `/Users/vita/Vitemis/Intatis/Packages/Intatis*`.
