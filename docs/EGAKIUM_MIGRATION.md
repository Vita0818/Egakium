# EGAKIUM_IDENTITY_CUTOVER

文档状态：当前 identity 与数据隔离边界
业务基线导入：2026-08-14
不兼容 hard cutover：2026-08-18
当前 Git root：`/Users/vita/Vitemis/Volans/Egakium`
产品版本：`v0.4`（build 50）

## 最终决定

Egakium 不再区分“用户可见品牌”和“内部技术 identity”。全项目只允许以下三种按语境使用的拼写：

| 形式 | 用途 |
|---|---|
| `Egakium` | 产品名、Swift/C/Objective-C 类型与模块、SwiftPM/Xcode target、App/Helper、目录和文件名 |
| `egakium` | CLI、scheme、workspace/config/data 文件夹、UserDefaults、协议/schema identifier |
| `EGAKIUM` | 环境变量、编译条件和 C/CMake 常量 |

该决定是 hard cutover，不是渐进迁移：

- 不提供旧产品名的 typealias、兼容 target、shim、adapter、redirect 或双写；
- 不探测、不导入、不回放 hard cutover 前的会话、配置、UserDefaults、凭据、bookmark、cache 或浏览器状态；
- 不在当前 identity 下复制旧数据，也不通过 fallback 搜索另一个产品目录；
- 不删除用户机器上既有的旧数据。它留在原位置，Egakium 只是永远不发现它；
- EventLog 内部仍可保留与当前 Egakium 数据格式有关的 additive decoder/recovery 逻辑，但它不构成跨产品数据迁移，也不得重新引入旧路径发现。

## 当前技术 identity

- Swift package：`Egakium`
- Swift products/modules/targets：`EgakiumCore`、`EgakiumProtocol`、`EgakiumProviders`、
  `EgakiumConversation`、`EgakiumArtifacts`、`EgakiumMultimodal`、`EgakiumSharedUI`、
  `EgakiumTools`、`EgakiumKnowledge`、`EgakiumPermission`、`EgakiumAgentKernel`、
  `EgakiumSkills`、`EgakiumCowork`、`EgakiumMCP`、`EgakiumMCPStdio` 以及相应内部 C/guard target。
- macOS target/App/executable：`EgakiumMac` / `EgakiumMac.app` / `EgakiumMac`
- iOS target/App/executable：`EgakiumiOS` / `EgakiumiOS.app` / `EgakiumiOS`
- CLI product/executable：`egakium`
- Xcode project：`Egakium.xcodeproj`
- macOS bundle identifier：`com.Vita0818.EgakiumMac`
- iOS bundle identifier：`com.Vita0818.Egakium`
- CEF host archive：`libEgakiumCEFHost.a`
- CEF Helpers：`EgakiumMac Helper` 及 Alerts/GPU/Plugin/Renderer variants
- CEF Canvas scheme：`egakium://canvas`
- authorization sidecar：`__egakium_authorization_context`
- workspace Session Canvas：`.egakium/canvas/<SessionID>/...`
- macOS/iOS Application Support root：`Egakium`
- user config/auth root：`~/.config/egakium/`
- 环境变量前缀：`EGAKIUM_`
- UserDefaults/schema identifier 前缀：`egakium.`
- 项目维护 Skill：`.agents/skills/egakium-skill-creator/`

## 配置与数据隔离

当前应用只创建和读取 Egakium-owned roots。核心入口包括：

- `~/Library/Application Support/Egakium/`
- `~/.config/egakium/egakium.json`
- `~/.config/egakium/egakium.jsonc`
- `~/.config/egakium/auth.json`
- workspace-local `.egakium/`
- `EGAKIUM_CONFIG` 和 `EGAKIUM_AUTH_FILE` 明确指定的用户路径

显式环境变量 override 是用户对 exact 文件的当前授权，不是旧 identity fallback。应用内部允许
`config.json` 等通用文件名出现在已经确定的 Egakium-owned 目录内；不得借此扩大到其他产品目录。

本次 hard cutover 不执行磁盘数据删除。旧 App Support、配置、Keychain 项、UserDefaults、CEF cache、
workspace metadata 或历史会话若仍存在，保留给用户自行处置；Egakium 不读取也不清理它们。

## 源码与构建切换范围

以下范围已统一改名，并以当前源码为唯一事实源：

- `Apps/` 下 macOS、iOS 和 CLI 的目录、入口文件、类型、imports 与 tests；
- `Packages/` 下所有公共/内部 target、source/test 目录、模块 imports、C headers 和 exported symbols；
- `Package.swift` products、targets、dependencies、paths 与 CLI product；
- `project.yml` project/target/scheme/package、bundle、module、executable、wrapper、icon、entitlement 和 CEF linkage；
- CEF CMake targets、bridge/helper sources、Helper bundle metadata、build output 目录和嵌入脚本；
- 配置/data/cache/diagnostics/workspace paths、UserDefaults、Keychain service、环境变量和 schema/protocol identifiers；
- tests、fixtures、scripts、release tooling、NOTICE、ThirdPartyNotices、Vendor ledger、活跃文档和项目 Skill；
- 文件与目录 basename，包括 App、Package、test、C symbol wrapper、icon、report 和 Skill paths。

这是一次物理路径切换；没有通过旧目录 symlink 或 build-time alias 维持双结构。

## Canvas / CEF 与 Cowork 边界

identity hard cutover 不改变已经确认的产品方向：

- macOS 主窗口仍只有一个“左 CEF Canvas、右 Cowork harness”的组合 presentation；
- 官方 CEF 仍是唯一 Canvas renderer，没有 WKWebView、第二 renderer 或 fallback；
- `CoworkViewModel`、Orchestrator、scheduler、MessageBus、PermissionEngine、EventLog 和 session lifecycle
  仍只有一套；
- fresh Session 使用 `.egakium/canvas/<SessionID>/index.html`；exact `@main` 编辑主入口；
- successful ordinary `spawn_agent` 获得 fresh generic child element document 和 durable descriptor；
- Chat/Code 入口只是 presentation-hidden，底层能力仍保留；iOS 仍是 Chat 子集。

完整 Canvas/Cowork 合同见 `docs/EGAKIUM_CANVAS_COWORK.md`，dependency-first/no-fallback 合同见
`docs/OPEN_SOURCE_REUSE.md` 和 Vitemis canonical
`/Users/vita/Vitemis/docs/DEPENDENCY_POLICY.md`。

## 保留但不改写的资产

| 路径 | 边界 |
|---|---|
| `.git/` | 保留当前仓库历史；hard cutover 不重写 Git 历史对象 |
| `OpenSource/` | 保持 26 个 mode-`160000` gitlink；不递归改上游仓库内容或指针 |
| `Chromium/` | 历史 Chromium 本地资产；不是当前 product dependency，不因 identity cutover 删除 |
| `.deps/` | 官方 CEF archive/distribution；当前 build 只通过 pinned config 消费，不重新下载或改写 |
| `docs/egakium-cef-baseline/` | 只读历史快照；不作为当前规则或产品 identity 来源 |
| `build/` / `.build/` | ignored 生成物；当前输出使用 `egakium-cef-runtime`、`egakium-xcode` 和新 SwiftPM module names |

hard cutover 前生成且带旧 identity 的 build/cache 目录已从工作区移动到
`/private/tmp/egakium-pre-decouple-generated-backup/`，属于可恢复的临时备份，不是产品输入。没有删除
用户 App Support、Keychain 或工作区数据。

## OpenSource Git 边界

2026-08-17 已将迁移时被拍平的 26 个 `OpenSource/<project>` 恢复为父仓库 gitlink，并补齐
`.gitmodules` 的公开 origin 与 `shallow = true`。identity hard cutover 不改变这些上游项目的名称、
内容、commit SHA 或 provenance；第三方名称不属于 Egakium 自有 identity，不能做品牌替换。

## 验证边界

2026-08-18 hard cutover 已验证：

- repo-owned source/path residue scan 对六种旧拼写返回零结果；
- `swift package dump-package` 成功解析全新的 product/target/path graph；
- `swift build` 成功，生成 `egakium` CLI 与全部 `Egakium*` Swift modules；
- `xcodegen generate` 生成 `Egakium.xcodeproj`；
- pinned official CEF Debug wrapper、`libEgakiumCEFHost.a` 与五个 `EgakiumMac Helper` 构建成功；
- `EgakiumMac` ARM64 Debug unsigned build 成功并嵌入 CEF；
- `EgakiumiOS` generic Simulator Debug unsigned build 成功；
- 完整 `swift test` 的最终结果记录在 `docs/TESTING.md` 和本次交付报告中。

这些验证不等于 Developer ID 签名、公证、staple、Gatekeeper、安装或旧用户数据迁移；后者明确不在
本次 hard cutover 范围内。
