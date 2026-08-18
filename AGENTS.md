# Egakium 项目常驻上下文

本文件继承 `/Users/vita/Vitemis/AGENTS.md` 中的 Vitemis 通用 Agent 规则。若本文件与通用规则冲突，在不违反系统和用户指令的前提下，以更具体、更严格的项目规则为准。

本仓库在 2026-08-14 导入一份既有 Apple-first Swift 工作树作为业务起点，并保留当前 Git root、
历史文档以及既有 Chromium/CEF 本地资产。2026-08-18 用户决定执行不兼容的 identity hard cutover；
当前产品版本是 `v0.4`（build 50），唯一产品与技术身份为 `Egakium` / `egakium` / `EGAKIUM`。
Swift 类型、模块与 package/target、macOS/iOS/CLI 入口、bundle identifier、C/Objective-C 符号、
配置与数据路径、UserDefaults、Keychain service、环境变量、协议保留字段、测试和活跃文档均已切换。
当前 Git root 是 `/Users/vita/Vitemis/Volans/Egakium`，Session Canvas 路径是 `.egakium/`。
应用不得探测、导入或迁移 hard cutover 前的对话、配置、凭据或缓存；旧用户数据不自动删除，
但属于另一个、不可见的 identity。完整边界见 `docs/EGAKIUM_MIGRATION.md`。

2026-08-15 用户进一步确认 Egakium 的新产品方向：macOS 主工作流以现有 Cowork runtime 为
底座，中央是一张每个 Cowork Session 独立初始化的 HTML/DOM 画布，右侧直接复用现有 Cowork
harness。每个画布元素是一份独立 HTML 小网页；exact `@main` 通过提示词负责全局布局、协调和
委派，ordinary sub-agent 默认在一次任务中编辑一个指定元素。该分工只是动态 prompt / TaskContract
约定，不是永久 Agent 类型、硬编码 hierarchy、Element owner 或新 lease。完整合同见
`docs/EGAKIUM_CANVAS_COWORK.md`。同日用户最终选择 Canvas 方案一：宿主只从固定模板初始化
Session `index.html`，之后 exact `@main` 可以通过现有 workspace file/patch 工具直接编辑整份
HTML/CSS/JavaScript；ordinary sub-agent 仍不得并发修改这份共享入口，可被委派到互不重叠的辅助或
元素 HTML 文件。该决定取代此前“主 HTML 永远 host-owned、`@main` 只能改布局投影”的设想。

2026-08-17 用户曾调整实现顺序：先在 `WKWebView` 原型上把主画布改造成可接收未来子 HTML
文档的元素容器，再继续正式 CEF；该“先做替代层、以后再换”的许可已被下述最新决定撤销。
2026-08-18 的 CEF cutover 已删除 `SessionCanvasRuntime`、WKContentWorld/WKNavigationDelegate、
WebKit 文件加载、目录轮询、`sessionStorage` layout override 和相关 fallback。可保留的 provisional DOM
contract v1 只存在于 source HTML：`#canvas` 的直接 `.egakium-element` 子项使用 stable-safe
`data-element-id`、title、x/y/width/height 和同 Session 相对 iframe；模板 CSS 由 CEF 直接渲染，宿主
不注入 DOM runtime。当前仍没有 Canvas EventLog、durable layout projection、native bridge 或正式
Element/layout revision schema，也没有宿主自研 drag/resize 层。

2026-08-18 用户最终明确项目级 **dependency-first / no-fallback** 规则：当用户指定、仓库已经采用，
或经许可证、provenance、安全与平台审查可采用的外部依赖提供相同能力时，必须直接集成该依赖的
官方能力；不得自行重写同等能力，不得增加替代 adapter、shim、compatibility layer、parallel
backend、临时 preview backend 或“先兜底、以后再换”的实现。允许的本地代码仅限官方 API 所必需
的最薄生命周期、类型、权限和 bundle 接线，不能重新实现依赖的核心能力。若依赖因版本、构建、
签名、许可证、平台或安全边界暂时不可接入，必须停止该能力实现、明确报告 blocker 并请求用户
决定；不得静默降级或自选替代技术。只有用户针对 exact 依赖、exact 范围和退出条件作出的新明文
决定才能例外。本项目继承 Vitemis canonical
`/Users/vita/Vitemis/docs/DEPENDENCY_POLICY.md`；项目内准入与 Canvas 具体化见
`docs/OPEN_SOURCE_REUSE.md`。

该规则对 Canvas 的结论是确定的：官方 CEF 是唯一接受的 macOS Canvas 网页渲染依赖。当前
`EgakiumMac` target 已直接接入 pinned official CEF
`151.3.17+gf059e67+chromium-151.0.7922.138` ARM64 Standard Distribution：使用 CEF 官方
`libcef_dll_wrapper`、external message pump、sandbox Helper sequence 与 AppKit child-browser API；
SwiftUI-owned `NSApplication` 的 CEF event/terminate 接线采用 official JCEF exact pinned
category/swizzling pattern 的最小派生，不使用无效的 `NSPrincipalClass` 假设；
最终 App 内含 versioned `Chromium Embedded Framework.framework`、五个标准 Helper、上游 LICENSE/
CREDITS。`CoworkCanvasHost` 只创建 `EgakiumCEFView`，通过 isolated memory-only request context 和
严格 Session-rooted `egakium://canvas` scheme 加载页面；不存在 WKWebView、WebKit 注入、renderer
切换或 fallback。CEF 缺失/hash 不符时构建失败，初始化失败时 Canvas 明确 unavailable。

同日用户进一步确定子元素起点：全产品只维护一份 host-authored
`SessionCanvasElementTemplate` 通用 child-document HTML，不为不同 sub-agent 设计不同模板。每个
成功的 ordinary `spawn_agent` admission 会由宿主自动选择 fresh `CanvasElementID`，并在新 agent 的
exact workspace root 下以 no-overwrite 方式创建
`.egakium/canvas/<SessionID>/elements/<ElementID>/index.html`。同一个
`SessionCanvasElementDescriptor` 会进入 `agent_spawn_requested` / `agent_spawned`，成功 ToolResult 与
`list_agents` 返回 `canvas_element_id`、workspace-relative path 和 template version，新 agent 的 trusted
system prompt 也自动得到这份真实文件的 exact descriptor；旧/manual attach worker 仅保留 identity-free
prompt copy fallback。模板自身仍不含 AgentID、ElementID、SessionID 或路径，也不授予 agent 写权限：
read-only child 获得宿主创建的文件但不能编辑，只有 read-write lease 才能修改。跨 EventLog/filesystem
边界采用 create-before-admission + replay proof：append 报错后先用 complete-known replay 判定 exact
batch 是否已因 WAL/lost-ack 提交；已提交则完成内存 admission，只有可证明未提交时才回滚本次仍为
原始模板的目录，无法证明时保留资源并 fail closed。宿主不得因此修改共享 `index.html`；exact `@main` 必须等待成功
ToolResult 后才创建 card 或在后续 round 委派。该 descriptor 只是 spawn provenance，不产生永久
Agent↔Element ownership，agent recycle 不删除元素，同一 Agent/Element 可在后续任务中重新组合。

同日用户曾确认一条双窗口调试路线；2026-08-16 用户在实际打开后进一步纠正该决定：产品只保留
一个 Cowork 窗口，必须一打开就是“左画布、右 harness”的原样左右拼接，不能再有会单独显示或被
macOS 恢复的 Canvas Window、`Open Canvas` 动作或第二个 `WindowGroup`。当前 `CoworkSessionView`
已以原生水平 split 将可复用 `CoworkCanvasHost` 放在左侧，将未改业务参数和行为的现有
`CoworkShell` 放在右侧；两者直接消费同一个 `CoworkViewModel` 与 exact Session Canvas。此前独立
Canvas 调试窗口的 value、resolver/model、view wrapper、scene 和 header action 均已移除，此纠正
取代“保留调试/备用入口”的旧表述。Session 启动仍在 fresh 七事件 bootstrap 后幂等创建
workspace-local `.egakium/canvas/<SessionID>/index.html`；Canvas 归 Session 所有，不能因组合视图的
打开、关闭或重建而新建、重置或停止。当前左侧已是嵌入同一 AppKit/SwiftUI 窗口的官方 CEF child
browser；只允许 `egakium`/`about`/`data`/`blob`，弹窗和网络 scheme fail closed。CEF lifecycle 在
`applicationWillFinishLaunching` 初始化，在 App runtime drain 后关闭全部 browser 并调用
`CefShutdown`。这只是正式网页 renderer 与资源边界；durable ElementID/layout/event schema、native
bridge、用户 layout persistence 和 Agent-driven 多元素 App E2E 仍未实现。

同日用户进一步要求先隐藏 macOS 主 sidebar 的 Chat 与 Code 模式入口，但明确不是删除产品能力。
当前 `EgakiumMacRootView` 的可见 navigation items 只有 Cowork，初始 selection 也是 Cowork；
`EgakiumNavItem.chat/code`、对应 View/ViewModel、session history、runtime、配置和恢复分支必须继续保留。
后续不得把“隐藏入口”误写成移除 Chat/Code target、源码、数据、协议或 CLI/iOS 能力；需要恢复入口时
应只调整 presentation visibility。

本文是 AI Agent 每轮进入本仓库时的入口文件。执行任何代码修改、配置修改、构建脚本修改或测试源码修改之前，必须先按顺序阅读并核对下列文档：

0. `/Users/vita/Vitemis/AGENTS.md`
0a. `/Users/vita/Vitemis/docs/DEPENDENCY_POLICY.md`
1. `docs/EGAKIUM_MIGRATION.md`
2. `docs/EGAKIUM_CANVAS_COWORK.md`
3. `docs/VERSIONING.md`
4. `docs/CURRENT_STATE.md`
5. `docs/MACOS_DISTRIBUTION.md`
6. `docs/PROJECT_MAP.md`
7. `docs/ARCHITECTURE.md`
8. `docs/DO_NOT_BREAK.md`
9. `docs/OPEN_SOURCE_REUSE.md`
10. `docs/TESTING.md`
11. `docs/NEXT_TARGET.md`（如果存在；CEF-only cutover 已完成，当前没有获准的下一业务目标）
12. `docs/COWORK_PRINCIPLES.md`（修改 Cowork / AgentKernel / MessageBus / 权限 / agent 编排前必读）

如果文档与源码、工程配置、测试或脚本冲突，必须以当前源码和配置为准，并在最终报告中明确指出冲突位置和采用源码为准的原因。

> 仓内现有 `docs/COWORK_AGENT_ARCHITECTURE.md` / `COWORK_TASK_CONTEXT_MODEL.md` / `COWORK_CURRENT_FINDINGS.md` / `COWORK_MIGRATION_PLAN.md` / `COWORK_AGENT_INVOCATION_MODEL.md` / `COWORK_V0_10_SMOKE.md` / `COWORK_V0_10_STATUS.md` 是 Cowork 设计文档与状态记录，可作为深入参考；`docs/COWORK_PRINCIPLES.md` 是其原则提炼。

## 工作目录检查

每轮开始先在项目根目录执行：

```sh
pwd
git rev-parse --show-toplevel
git status --short
```

要求：

- `pwd` 与 `git rev-parse --show-toplevel` 必须指向同一个仓库根目录：`/Users/vita/Vitemis/Volans/Egakium`。
- 如果当前目录不是 Git root，停止修改，只报告路径问题。
- 读取 `git status --short` 后，先区分用户已有改动与本轮计划改动；不得覆盖、回退或清理用户已有改动。

## 修改边界

当前业务基线是 Apple-first、Swift-native 本地 AI 工作区（Swift 多 target，SwiftPM + XcodeGen），
含三个产品面：Chat（普通多模态对话）/ Code（单 agent 本地工作区）/ Cowork（多 agent 本地工作区协作）。
macOS 是全量产品；iOS 是 chat 子集。允许按 `docs/OPEN_SOURCE_REUSE.md` 选择性复用兼容许可证的
公开源码；当前实现是否实际包含上游代码以 `NOTICE.md` 为准。

Egakium 的目标产品层只组合和扩展 macOS Cowork：在现有 harness 外增加 Canvas + 右侧 sidebar
布局，保持 `CoworkViewModel`、composer、projection、Orchestrator、scheduler、MessageBus、
PermissionEngine、EventLog 和 lifecycle 语义不变。Session `index.html` 由宿主从固定模板初始化，
之后 exact `@main` 可以直接编辑整份页面；ordinary sub-agent 若参与，应编辑互不重叠的辅助/元素
document，并由 `@main` 集成或引用。ordinary `spawn_agent` 成功 admission 还会在 child exact
workspace root 下 host-provision 一个 fresh generic element document；这是有明确 permission intent、
additive event descriptor、失败 compensation 的窄 bootstrap，不授予额外 write lease，也不修改主
`index.html`。禁止多个 Agent 并发修改同一主 HTML。Canvas 当前不进入 iOS。
Canvas renderer 必须继续直接使用已确认并 pinned 的官方 CEF 依赖；不得重新引入 WKWebView、另写
浏览器适配层或保留双 renderer fallback。现有本地 CEF 代码只能保持为官方 API 的最薄 binding、
生命周期、bundle/Helper、scheme 和既有权限边界接线，不得重写 Chromium/CEF 已提供的渲染或浏览器
能力。更新 CEF version/platform/archive/hash、Helper/sandbox 策略或架构属于新的依赖审查任务。
当前 macOS Cowork detail 已按用户确认使用原生水平 split 原样组合：左侧 `CoworkCanvasHost` 读取
同一 `CoworkViewModel.canvasDocument`，右侧继续使用既有 `CoworkShell`。不得重新增加独立 Canvas
窗口、scene、header action 或第二套 presentation；不得为组合视图复制 Cowork runtime，也不得把
视图生命周期当成 Canvas 生命周期。后续渲染器替换不得重写 CanvasHost 的 Session 输入边界或
harness 业务链路。
macOS 主 sidebar 当前只展示 Cowork 模式；Chat/Code 只是 presentation-hidden，底层实现与数据边界
不变。不得用删除 enum case、switch branch、View/ViewModel、runtime 或历史存储的方式实现入口隐藏。

2026-08-17 用户要求把迁移时被拍平的 `OpenSource/` 恢复为父仓库 gitlink。当前 `.gitmodules`
登记 26 个 shallow 上游仓库，父 index 对每个 `OpenSource/<project>` 只保存一个 mode `160000` 的
精确 commit SHA；这些 SHA 与导入基线当时记录的 gitlink 一致。`OpenSource/` 仍只是开源评估 checkout，
不是 SwiftPM/XcodeGen path dependency 或已经获准分发的 runtime。不得再次把子仓库内容拍平成父仓库
普通文件，也不得在没有用户逐仓库明确授权时递归 stage、commit、push 或改变子仓库指针。

根目录 `Chromium/`、`.deps/` 与 `build/` 是业务基线导入前已经存在的本地 Chromium、官方 CEF 下载/
解包和构建资产。当前 `config/cef.cmake`、CEF CMake host、XcodeGen
pre/post build phase 已正式消费 `.deps/cef` 中 exact pinned 发行包并把生成物写入 ignored
`build/egakium-cef-runtime`；`Chromium/` 和其他旧 `build/` 内容仍不是产品依赖。未经用户明确要求不得删除、
覆盖、迁移或重新下载这些资产，不得绕开 pin 另写 WKWebView/自研 renderer 兜底；Egakium 自己的
SwiftPM 产物目录仍是 `.build/`。

`docs/egakium-cef-baseline/` 是业务基线导入前的 CEF 文档只读历史快照。除非用户明确要求修订历史，
否则不要修改其中内容；当前规则与状态以根 `AGENTS.md`、`docs/EGAKIUM_MIGRATION.md` 及活跃 `docs/` 为准。

根 `.agents/` 包含项目维护用的
`egakium-skill-creator` 资料。文件存在不等于当前 Agent 会话已经注册该 Skill；只有当前会话的
available-skills 清单实际列出或用户明确触发并且运行时可读取时，才按对应 `SKILL.md` 使用，不能
仅凭目录存在宣称能力可用。

macOS 只通过 Developer ID 签名、公证和直接下载分发；不做 Mac App Store
版本。`EgakiumMacAppStore`、`.macAppStore` 与 App Store entitlements 是源码中
尚未删除的遗留实现，不是产品面、设计约束、默认测试矩阵或 release gate。
后续不得仅为 Mac App Store App Sandbox 裁剪功能或增加替代实现，也不要默认
构建/修复该 target。此决定不弱化 Egakium 自有权限链、Workspace confinement、
managed-terminal Seatbelt、Hardened Runtime、签名/公证或 iOS 平台边界；精确
合同见 `docs/MACOS_DISTRIBUTION.md`。

未来常规任务可以按用户要求修改业务源码；但在只要求项目自查或文档更新的任务中，只允许修改：

- `AGENTS.md`
- `docs/` 下的项目说明文档

除非用户明确要求，不要修改：

- `Apps/`（EgakiumMac / EgakiumiOS / egakium-cli）
- `Packages/`（当前 14 个公共库、3 个内部 C/guard target、开发期 MCP
  conformance executable 及其 Tests；精确清单以 `Package.swift` 为准）
- `Package.swift`
- `project.yml`
- `Makefile`
- `NOTICE.md`

## 禁止事项

- 不执行破坏性 Git 操作：`git reset --hard`、`git clean -fd`、`git checkout .`、强制 push、删除用户未提交文件。
- 未经用户明文要求具体 Git 操作，不 add、不 commit、不 push、不创建 PR；编辑、整理、修复、验证或准备工作都不等于提交请求。
- 若用户要求提交，只提交当前 Git root 中与本任务相关的文件；不得递归进入、暂存、提交或推送子仓库、submodule、nested Git repo 或依赖 checkout。
- 不引入新依赖，不改构建脚本，不改测试源码，除非任务明确要求。当前第三方依赖与
  vendored 派生源码以 `NOTICE.md`、`ThirdPartyNotices/` 和
  `docs/OPEN_SOURCE_REUSE.md` 为准；任何新增或升级都须先过许可证与 provenance 审查。
- 当已存在具备相同能力、用户指定或已通过准入的外部依赖时，禁止自研替代实现、adapter、shim、
  compatibility layer、parallel backend、preview backend 或 fallback。不得以“先跑起来”“方便测试”
  “以后再替换”为理由绕过；接入受阻就报告 blocker，不得静默换技术。最薄官方 API binding 不等于
  重写能力，但必须在设计和测试中证明只做接线。
- 不把密钥、token、证书私钥、shared secret、账号密码、完整指纹、完整 API 响应、完整转写文本或个人隐私路径写入文档。
- 不绕过 3 层权限门（DeterministicPolicyGate / ModelPermissionReviewer / PermissionEngine）、PathConfinement 工作区边界、SecretScanner、Mediator 秘密拦截或 Keychain 凭据隔离。
- 不把 Cowork 实现为硬编码递归 agent 树（main/coordinator/worker/leaf 永久角色）；遵循 `docs/COWORK_PRINCIPLES.md`。
- 不把“一个 sub-agent 默认编辑一个元素 HTML”的 prompt 约定实现为永久 Agent class、Element owner、
  ElementLease 或 capability inheritance；允许后续任务重新委派或由同一 Agent 顺序编辑其他元素。
- 不为 Egakium Canvas 重写现有 Cowork harness、CoworkViewModel、Orchestrator、scheduler、
  MessageBus、permission queue、EventLog 或 session lifecycle；右侧 harness 只允许必要的 UI 组合/窄栏适配。
- 主界面只允许一个左右拼接的 Cowork presentation：不得重新增加独立 Canvas Window、value-driven
  `WindowGroup`、`Open Canvas` header action 或窗口恢复 resolver；组合视图不得自建第二套
  CoworkViewModel、Orchestrator、scheduler、MessageBus、permission queue、EventLog、
  AppSessionRuntime 或 Session authority，打开/关闭也不得创建、重置、删除或停止 Session Canvas。
- macOS sidebar 的 Chat/Code 入口只能隐藏，不能删除对应 `EgakiumNavItem` case、detail branch、
  View/ViewModel、session/runtime/history/configuration 或恢复能力；默认可见/初始模式为 Cowork。
- `OpenSource/` 必须保持 `.gitmodules` + 26 个 mode-`160000` gitlink 的父仓库边界；父仓库不得
  递归跟踪其源码。更新任一 SHA、origin、shallow 策略或子仓库内容属于单独的上游/Git 操作，必须
  经过明确授权和 `docs/OPEN_SOURCE_REUSE.md` 的 provenance/许可证核对。
- 不让多个 Agent 并发 patch 同一 Session 主画布 HTML。对共享入口，宿主只拥有首次模板创建，
  exact `@main` 是当前 `index.html` 的唯一协调编辑者；ordinary spawn 的 host-owned child-template
  provisioning 只能创建新 agent 自己 workspace 下的 fresh no-overwrite element file，绝不能顺带
  patch 共享入口。ordinary sub-agent 若被委派，应使用互不重叠的辅助/元素 HTML 路径并由 `@main`
  集成；不得把 spawn descriptor 或这一纪律硬编码成永久 owner/lease。
- 不得在 `CoworkCanvasHost` 或别处重新引入 WKWebView Canvas renderer、DOM 注入、文件轮询、
  renderer adapter、第二 backend 或 fallback。现有 `EgakiumCEFView` 只能保持为 CEF 官方 API 的最薄
  child-view/request-context/scheme/lifecycle 接线；CEF 缺失时必须 fail closed/报告不可用。
- 不让 `AgentLoop` 直接同步递归调用另一个 `AgentLoop`；用 mailbox / scheduler / event flow。
- 不让 worker 默认获得 coordinator 工具（spawn_agent / remove_agent / delegate_task）；能力须经 `CapabilityLease` 显式授予。
- 不使用泄露/私有源码或 prompt，不复制第三方产品名称、Logo、图标、截图、UI 资产、商标性外观或品牌文案。兼容许可证的公开源码、公开 model-facing prompt 和测试可以选择性复制、翻译或修改，但必须先固定上游 commit、核对文件/依赖许可证、记录 provenance、更新 `NOTICE.md`，并遵守 `docs/OPEN_SOURCE_REUSE.md`；不得把派生实现错误标成独立原创。
- 不让复用的外部源码、依赖或 runtime 绕过 PermissionEngine、CapabilityLease、WorkspaceLease、PathConfinement、SecretScanner、Mediator、durable tool execution 或 EventLog；Apple 平台继续以 Swift 原生为主，非 Swift runtime 不得隐式进入 iOS target。
- 不弱化平台边界：iOS 不得链接 shell/git/patch/local-agent workspace 模块，不得包含本地 workspace Agent 执行。
- 不把事件日志 JSONL schema、Envelope 格式、`seq` 单调性、ArtifactStore 索引格式当作一次性内部细节随意改动。

## 项目理解要求

修改前至少确认：

- 入口：`Apps/EgakiumMac/Sources/EgakiumMacApp.swift`（`@main struct EgakiumMacApp`，全量 macOS）、`Apps/EgakiumiOS/Sources/EgakiumiOSApp.swift`（`@main struct EgakiumiOSApp`，chat 子集）、`Apps/egakium-cli/Sources/EgakiumCLI.swift`（CLI）。
- Chat 链路：`ChatViewModel` → `GoalInputParser`（行首 `/goal` 只生成可选 Goal 元数据，provider 收到清洗后的文本）→ `ChatLoop`（无工具）→ `EventLog`(JSONL append-only) → `ConversationProjection`。
- Code 链路：`CodeViewModel` → `GoalInputParser` → 共享 headless `AgentRuntime.code` → `AgentLoop`（maxIterations 50）→ `ContextBuilder` + `RuntimeEnvironmentManifest` → `OpenAIWireProvider` → `runTool` → `PermissionEngine`（3 层门）→ `EventLog` → `CodeProjection`。
- Egakium Canvas 当前 CEF-only 链路：fresh Cowork 七事件 bootstrap → `CoworkViewModel` 独立、幂等、无
  provider 地创建 `.egakium/canvas/<SessionID>/index.html` → exact `@main` root prompt 获得该精确
  workspace-relative 路径并可用既有 file/patch + permission 链直接编辑 → `CoworkSessionView` 用原生
  水平 split 将读取 `vm.canvasDocument` 的 `CoworkCanvasHost` 放左侧、原 `CoworkShell` 放右侧。产品
  没有独立 Canvas scene/window/action。`CoworkCanvasHost` 只嵌入 `EgakiumCEFView`；官方 CEF child
  browser 使用 per-view memory-only request context，通过 strict Session-rooted `egakium://canvas`
  scheme 加载 `index.html`/relative child assets，阻断网络和 popup。CEF Framework、五个 sandbox
  Helpers、external pump、init/shutdown、ARM64 build/bundle 和 notices 已接线；没有 WK/WebKit 或
  renderer fallback。`#canvas` 下 provisional `.egakium-element`/iframe 目前只由 source HTML/CSS
  表示，不再有宿主注入的 drag/resize/runtime；durable ElementID/layout/event/bridge schema 仍待未来
  明确授权。ordinary sub-agent 的辅助/元素 HTML 范围来自当次
  TaskContract/context。成功的 ordinary `spawn_agent` 会在新 agent 的 exact workspace root 下自动创建
  fresh generic element document，并把 validated descriptor 原子关联到 spawn events、ToolResult、
  `list_agents` 与该 agent prompt；read-only child 仍无编辑权限，manual/legacy attach 才使用
  identity-free prompt fallback。该关联不形成永久角色/ownership，recycle 不删除文件，也不得并发编辑
  共享入口。
- Cowork 链路：`CoworkViewModel` → `GoalInputParser` + `CoworkMentionRouter` → `SubmittedIntentStore`（outbox → 原子 `user_message + queued`）→ `Orchestrator.runtime`（先取得 session writer lease）→ FIFO scheduler → 共享 headless `AgentRuntime.cowork` → `AgentLoop` → `PermissionEngine` → durable tool execution ticket → executor → `EventLog`；`MessageBus` → `Mediator`。fresh Cowork 在任何模型请求前，以同一原子 7-event batch 登记完整 session settings、`@main` 与 `@permission-reviewer` 各自的 workspace/capability lease 和 identity；两者共享 canonical workspace，但 exact inference binding 分别由 main/session selection 与顶层 `permission_reviewer_model` 决定，identity/lease 也独立，reviewer 为 read_only、空工具/通信/委派且 depth 0。`permission_reviewer_model` 只接受已配置的 `<provider>/<model-id>` base profile，不增加 UI；字段缺失时仅在配置解析层一次性继承同一 JSON 文档的顶层 `model`，兼容来源缺失/未知、显式空值、错误类型、不可解析 route 或已选配置整体损坏/不可读必须让 reviewer fail closed，不能回退 UI/session default、live/historical `@main` 或其后续 rebind。GoalVerifier 继续冻结首个可解析的 exact `@main` binding，与 reviewer 配置互不替代。GUI/CLI 默认启用该保留控制面 agent，`AgentPermissionResponder` 把结构化 `PermissionReviewTask` 交给独立 `PermissionReviewControlPlane` FIFO/single-flight；reviewer 有独立 timeout/cancel 与可选 soft token warning，不占普通 scheduler 槽，只返回 `allow` / `deny`。reviewer 默认不得注入 `temperature`、output-token 或字符上限；只有用户/host 显式策略或真实上游/上下文约束存在时才可传递相应控制。request/settled 均先落 EventLog，allow 只有 settled 成功后生效；pre-submit caller cancel 直接返回 typed deny、不创建 review lifecycle；timeout、malformed、provider/persistence failure 和已登记 review 在 terminal-claim 前被观察到的 cancel durable deny 当前调用，不转 GUI 人工等待；claim 后 cancel 保留唯一 settlement 但最终 authorization delivery deny。每个 provider dispatch 都使用 exact `{reviewTaskID, nonce}` generation；provider/timeout 竞争同代首 terminal，caller cancel 由同步 request token、actor path 与下游围栏共同处理。production 按冻结 reviewer exact binding 逐代 fresh-resolve provider wrapper；timeout/cancel 只影响当前 call，若已有 active generation 就只 retire 该代，late/duplicate output 无权影响新代或执行工具。`ToolCallingProvider.stream` 必须立即返回 request-owned stream，并传播 consumer termination；不得用 `Task.detached` 宣称支持同步永久阻塞实现。旧 `provider_still_stopping` 只保留 legacy decode。Phase A 后 GUI composer 始终可编辑，Send 先冻结并持久化本地提交；reviewer 未就绪只显示状态并使后续 ask-class tool fail closed，不阻止普通主请求。CLI `/auto` 重启，只有用户明确 `/default` 才进入人工模式。审查者不得作为普通 send/delegate/message/ask 目标，不得运行嵌套 `AgentLoop`。
- Cowork automatic 的 request-owned provider-facing business schema 增加 required string `__egakium_authorization_context`；任何 `strict:true` function 的 decorated copy 必须递归满足 `required == properties.keys` 与 `additionalProperties:false`，上述 strict object 不变量违规必须在发网前 typed fail closed。`tool_search` 本身保持原样，但其 request-owned `tool_search_output` 中延迟发现的 function/namespace 子工具也必须装饰；durable output 不变。原 ToolDescriptor/business required/executor schema 不变；宿主仅在 deterministic gate 实际进入 automatic ask 时消费并验证该字段，deterministic allow/deny 忽略其语义。acting model 在原 business function call/generation 内用这一句话说明“为什么这个 exact action 服务当前任务”，不得复制全文、声明风险或自行给出权限结论；不再有第二次 acting-model Reporter 请求。宿主先剥离 sidecar，再用 stripped canonical business arguments 做原 schema、gate、authorization、durable history 与执行。live reviewer 只收到 complete safe business arguments、complete same-generation sidecar 和 mechanical host binding/gate/lease/action facts；不得发送 TaskContract objective/role/deliverable、causal userGoal、用户消息、assistant history、PDF 或图片原文。valid sidecar 只在当前 turn 的 acting-model 内存 conversation 中保留为正确格式示例，raw sidecar 与 transient exact-args 不进入 EventLog/permission lifecycle，durable history 仍只保存 stripped business call。missing/malformed/secret-bearing sidecar 是可纠正的 acting-model tool-input failure：只写 failed/runtimeFailed `tool_result`，不创建 `permission_request` / `permission_resolved`、不调用 reviewer、也不消耗 permission denial fuse；同 business args 修正后仍可进入 reviewer。binding/authorization snapshot 无法证明则另行 typed fail closed。manual/nonautomatic 模式出现保留字段必须在业务执行前拒绝。automatic responder 必须实现 bound-invocation overload，live cached/duplicate request 必须复验 exact transient invocation，recovered allow 不得重新交付；唯一无 acting-model sidecar 的 automatic `agent.attach` 必须走 dedicated host-admission entry，并核对 exact admission identity 与先行 durable events。Cowork 若误注入 in-engine reviewer，control-plane 前必须 fail closed；shipping 默认不得这样配置。reviewer 无工具，只接受短 reason + final-line ASCII `ALLOW` / `DENY`；对 live bound invocation，reviewer reason 与 provider diagnostic 不得进入 durable lifecycle/tool-result，改用固定宿主文案。旧 Reporter context/type 仅保留 legacy decode/reconciliation，不得恢复第二次 acting-model dispatch。acting model 仍可能在普通 assistant 文本中自行复述 sidecar，该普通文本按既有消息规则持久化；malformed acting-provider error preview 仍依赖通用 bounded/secret sanitizer。live 路径也没有固定 sidecar byte ceiling 或 `review_input_too_large` admission，未来上限只能由真实 route budget 推导，不得把这些后续能力写成当前事实。
- Cowork run/mailbox 终态：只有 exact `@main` root 可见 `finish_run` / `stop_run`，模型只给 reason，所有 identity 由宿主绑定；close intent 先成为 in-process admission tombstone，EventLog first-write claim 必须先于既有 admission 等待与 exact-run drain 落盘，user/runtime/host-lifecycle source 保真，恢复时不得复活，普通 final 不伪造显式 claim。mailbox 按 authority class 收窄：ordinary message one-way/no ACK，information request 只允许一个 exact `reply_message(inReplyTo:)` terminal，information reply receipt 不得再 reply/ACK；确需继续时用 fresh `request_information(based_on: reply MessageID)`，保留 conversation root。因此 `information_replied` 只终结当前 correlation，不得成为长期协作的全局回复禁令。
- Code/Cowork 的 model-facing 因果合同：同一 assistant response 的 multi-call batch 既不是 transaction，也不是 concurrency request/guarantee，只能包含互相独立且对任意 host execution order 都正确的 calls；任何 identity/ID/attachment/state 依赖必须等待前置调用成功 `ToolResult` 后在下一 tool-call round 使用，planned/future object 不得冒充已存在。WorkTask 是当前 Cowork Session 内的独立记录，不含 Run、Goal、Agent 或 Turn owner；`task_create` 不分配 agent。`delegate_task` 只能使用已经 attached 的 data-plane agent，省略 target 时也只选择现有 idle worker；需要新 agent 时必须先独立 `spawn_agent` 并等待成功 ToolResult。production `task_create` / `task_update` 只有首个 WorkTask EventLog append 前的 Orchestrator preflight rejection 可 typed `not_started`；append/persistence/lost-ack 仍是 unknown/manual，不得按错误字符串或 `EgakiumError` case 全局推断安全重试。内部 delegation 必须先完成 preflight/Mediator，再以一个 EventLog batch 提交 message、delegation、lease、invocation、queue 与 WorkTask linkage；batch 前拒绝不得留下部分事实。
- 权限 3 层：`DeterministicPolicyGate`（纯函数、模型无关、deny 终局；普通写入/网络/exec 进入 ask 流）→ `ModelPermissionReviewer`（只能收窄 gate `pass`，不能放行 hard deny）→ `PermissionEngine`（`askUser` 交给当前 `PermissionResponder`；Cowork 自动模式只接受 control-plane allow/deny，人工模式须由用户显式切换）。
- Phase C 权限/turn 合同：每个新 Chat/Code/Cowork turn 使用稳定 `TurnID` 并追加唯一语义的 `turn_outcome`；权限请求携带 turn/tool-call/authorization correlation 与 manual/automatic mode。`EventLog.registerPermissionRequest` 对同一 RequestID first-write-wins，`settlePermissionRequest` 在 complete-known history 与跨进程锁内执行 first-terminal CAS：exact duplicate 幂等，冲突 payload/terminal fail closed。人工 `Decline Call` 只写当前 call 的 typed denied `tool_result` 并允许模型继续；`Cancel Turn` 写 permission terminal 后中断整个 turn，禁止伪造 denied tool result。user/policy/reviewer/sandbox/runtime/cancel 必须保留 typed source；明确的 sandbox wrapper startup denial 结算为 `sandbox_denied/not_started` 且不自动 retry，普通 nonzero/EPERM 不得误分类。权限投影保持 FIFO，重显复用同一 RequestID，任意一项终结不得重排其余项；取消/终止必须先 drain tool/provider 清理，再写 task/turn terminal 并恢复 caller。
- Phase L 应用生命周期：macOS 的 Chat/Code/Cowork runtime 由进程级 `AppSessionRuntimeManager` 按 exact `{SessionKind, SessionID}` 持有，窗口只持有当前展示选择；切换 mode/session、Command-W 或关闭最后窗口不得隐式 stop。删除 session 必须先精确 drain 对应 runtime，其他窗口收到 removal 后退出已删除详情。Command-Q 先关闭新操作 admission，再同时广播所有 runtime stop，并在有界 deadline 后允许进程退出；超时不伪造 settled。冷启动只 replay/reconcile：历史 active Goal durable 转为 paused（达到预算则 budget-limited），历史 running/stopping 由既有恢复路径显示 interrupted，不自动调用 provider；只有明确 Retry、Resume、Send 或 CLI `/auto|/default` 后的显式 data-plane 动作才可继续。Chat/Code/Cowork shutdown 均须取消并等待本 runtime 已登记的 provider/tool/operation task，再释放权限 waiter、subscription 与 workspace scope。
- 平台边界：iOS 是 macOS 真子集（chat/multimodal/providers/artifacts，无 Tools/Permission/AgentKernel/Cowork）；`PlatformProfile.current` 默认 `.iOS`（最受限）。
- macOS 分发边界：唯一发行 App 是 Developer ID/direct-distribution
  `EgakiumMac`。不得把遗留 `EgakiumMacAppStore` 的 App Sandbox 限制带回
  产品设计、依赖选择或默认验证；不得把“无 App Store 约束”误解为可以移除
  PermissionEngine、Lease、PathConfinement、SecretScanner、Seatbelt 或
  Hardened Runtime。
- 持久化：`EventLog`（`~/Library/Application Support/Egakium/<session>/events.jsonl`）是 session canonical truth；append/batch 在跨进程锁内分配单调 `seq`，settings revision 也在同一事务边界分配，返回值/subscriber 发布实际落盘 bytes 反解的 canonical Envelope；production Cowork runtime 全生命周期持有 writer lease，旧 JSONL 必须继续可解码。`session.json` 是 owner-only、schema v2、可由 EventLog 重建的派生投影，含 `projectedThroughSeq`、settings revision、Cowork settings、agent/workspace/capability 摘要与 migration marker；缺失、损坏、落后或伪造领先时 EventLog 胜出，合法未知 future event 时旧程序不得覆盖投影。`workspace-access.plist` 是 session-owned、schema v1、owner-only binary plist，只保存 canonical path、opaque security-scoped bookmark 与 primary 标志；bookmark bytes 不得进入 JSONL/session.json，App 以 RAII lease 成对持有 scope，恢复时必须先启用 scope 再校验 canonical identity。共享 capability 只有 settings + live roster 都证明零引用才可清理；primary 在 UI/方法/store 默认拒删，只有未成立的创建事务失败回滚可显式删除。旧 Cowork settings/bookmark UserDefaults 仅是一次性迁移输入：必须按具体 session/path 核对来源、迁完全部所需 capability、读回验证并写 durable marker 后才清理，失败保留以便重试。`ArtifactStore` 保存 blobs + `index.json`。全局 `UserDefaults` 仍保存 provider catalog（`egakium.providerCatalog.v1`）与聊天页当前选择（`egakium.providerSelection.v1`，另有 `egakium.baseURL`/`egakium.model` 兼容镜像）；高级 macOS JSON/JSONC 配置继续按 `EGAKIUM_CONFIG`、`~/.config/egakium/egakium.json[c]`、app support `egakium.json[c]` 与旧 `~/.config/egakium/config.json` 兜底优先级读取。provider/model options/variants 必须按原始 JSON 保真到 wire adapter，凭据只从 Keychain/env/file/auth/config 懒加载，不得写入事件、投影或项目文档。
- Phase A durable 文件：`submitted-intent-outbox.json` 是 session-owned schema v1 owner-only 暂存，只在 canonical `user_message + queued(attempt 1)` 原子落盘前存在；`SubmissionID` first-write-wins、attempt one-based 单调、retry 复用 exact task 且不重复 user message。`ArtifactStore` 的 root/blobs/index/lock 必须 current-UID、no-follow、owner-only/single-link，索引在稳定锁内 read-merge-atomic-write；unsafe mode/symlink/hardlink fail closed，无法证明 rename durability 时返回 `commitUncertain`。
- production Code/Cowork registry 不暴露 raw `run_shell`；macOS DeveloperID 与 CLI 的 shell-capable Code/Cowork runtime 改为显式提供 runtime-owned `exec_command` / `write_stdin` managed terminal。它是真实持久进程/PTY，但每次启动和后续输入仍必须经过 ToolRegistry、CapabilityLease、PermissionEngine 与 durable tool ticket，并按 exact session/agent/task/attempt/WorkspaceLease/root identity 隔离；默认断网，macOS 走 Seatbelt，取消、task terminal 与 runtime shutdown 必须先 drain 进程。交互输入不得原样进入 EventLog/permission preview，延迟回显也必须清洗；危险命令 guard 必须跨调用跟踪已支持的行输入，无法可靠还原的 cursor/completion/history/escape/keymap 改写 fail closed，partial-write uncertainty 必须终止 session。terminal executor 必须把不可移除的敏感凭据路径清单并入任何新旧 WorkspaceLease，并以大小写无关的 Seatbelt denied rules 执行。read-only worker、reviewer、iOS 与禁用 shell 的 host 不得看到这两个工具。不得重新启用 raw `run_shell`，不得退回裸 shell；Linux 仅在 bwrap 可用时运行，否则 fail closed，PTY 当前仍不支持。structured browser/document backend 与 managed terminal 分流，但同样必须有 timeout/cancel 与进程清理。
- 普通 Office/HTML/EPUB 读取不再暴露聚合 `document_read`，而是五个 exact 工具 `read_docx` / `read_pptx` / `read_xlsx` / `read_html` / `read_epub`。每个 schema 只有 `path` 与可选 `maxCharacters`，格式由工具名固定，统一通过固定 Docling high-level converter 输出有界 Markdown；不得恢复 model-authored format/options/backend、手写对象遍历或 raw Docling dict。五个 reader 的 intent 为 exact `structured_read_only + safeToReplay`：解析失败必须结算为 failed observation 并允许同批其他读取继续，不能升级成整轮终止；该语义不得扩宽到 OCR、写入、网络或任意 exec。fresh lease 发五个 exact capability；legacy `documentRead` 只为旧 session 映射到五个新 reader，不恢复旧 concrete tool。PDF 普通读取仍走 `read_pdf`，Docling PDF 只保留显式 OCR 路径。
- 安全：`KeychainStore`（generic-password，凭据引用 `KeychainRef`；`KeychainSecretResolver` 仅在真实 provider 请求中按 keychain/env/file/auth JSON/Egakium-owned OpenCode-compatible config `options.apiKey` 懒加载 secret 并做进程内缓存；macOS auth JSON 默认先看 `~/.config/egakium/auth.json`，再兼容 `~/.local/share/egakium/auth.json`；不默认读取 `~/.local/share/opencode/auth.json`）、`PathConfinement`（拒 `..` 与越界）、`SecretScanner`、Developer ID Hardened Runtime，以及 managed terminal 自有的 workspace-scoped Seatbelt/default-network-deny；这些安全边界与已取消的 Mac App Store App Sandbox 产品约束无关。

不确定的模块必须标注 `UNKNOWN` 或 `需要后续确认`，不要编造。

## 文档索引

- `docs/PROJECT_MAP.md`：目录、target、入口、关键文件、生成物和脚本地图。
- `docs/EGAKIUM_MIGRATION.md`：Egakium identity hard cutover、数据隔离、保留资产与验证边界。
- `docs/EGAKIUM_CANVAS_COWORK.md`：已确认的 Cowork-first / Canvas-first 产品合同、方案一
  `@main` 直编 `index.html`、CEF-only renderer、harness 复用边界与待实现 durable 元素方向。
- `docs/MACOS_DISTRIBUTION.md`：macOS Developer ID 直接分发决策、遗留
  App Store target 状态、仍须保留的运行时安全边界和默认验证矩阵。
- `docs/ARCHITECTURE.md`：总体架构、主要链路、数据模型、权限与安全机制。
- `docs/CURRENT_STATE.md`：当前真实状态、已有能力、风险、工作区改动。
- `docs/TESTING.md`：环境、构建、测试、lint/format 与手动验证方式。
- `docs/DO_NOT_BREAK.md`：工程禁区、数据格式、协议、路径和回归要求。
- `docs/OPEN_SOURCE_REUSE.md`：开源源码/公开 prompt/依赖准入、provenance、Apple-first 集成、NOTICE 与上游升级规则。
- `docs/NEXT_TARGET.md`：CEF-only cutover 的完成状态与尚未获准启动的后续 durable Element 阶段。
- `docs/egakium-cef-baseline/`：业务基线导入前的 CEF 项目文档历史快照。
- `docs/COWORK_PRINCIPLES.md`：Cowork 架构原则（agent 身份/任务契约/能力租约/上下文投影/递归禁止/安全边界/实现顺序/测试期望）。

## 完成标准

完成任务前至少做到：

- 说明本轮实际阅读/检查过哪些源码、配置或测试。
- 只修改任务范围内文件。
- 保留用户已有改动。
- 运行与任务相称的检查；文档任务至少运行 `git diff --check` 与 `git status --short`。
- 将本轮已完成的持久性改动及时回写到相关项目文档；若无需更新文档，最终报告说明原因。
- 如未运行构建或测试，最终报告必须明确写"未运行构建/测试"。

## 最终报告格式

最终报告建议包含：

1. `MODEL_CHECK_RESULT`：当前模型名称；无法确认时写无法确认。
2. `PATH_CHECK_RESULT`：`pwd`、Git root、是否匹配预期。
3. `FILES_WRITTEN`：新增/修改文件。
4. `PROJECT_AUDIT_SUMMARY`：识别到的项目结构、主要模块和关键链路。
5. `DOCS_CONTENT_SUMMARY`：各文档内容摘要。
6. `VALIDATION_RESULT`：实际运行命令与结果。
7. `UNCERTAINTIES`：无法确认、需要人工确认的点。
8. `NEXT_RECOMMENDED_ACTION`：下一步建议；不要自动继续改业务源码。
