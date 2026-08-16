# EGAKIUM_CANVAS_COWORK

文档状态：用户已确认的 Ekagium 产品合同；方案一最小双窗口原型已实现，CEF/元素 schema/最终合窗待实现
确认日期：2026-08-15
当前业务基线：Ekagium v0.2（build 49；源码与技术 identity 仍来自 Intatis SwiftPM/XcodeGen 基线）
适用范围：macOS Ekagium 主产品面、Cowork UI 组合、Canvas/Element 模型与 Agent 协作边界

## 一句话结论

Ekagium 是一个 **Cowork-first、Canvas-first** 的多 Agent 空间工作台：中央是每个
Cowork Session 独立初始化的 HTML/DOM 画布，右侧直接复用现有 Cowork harness。宿主只负责从
固定模板首次创建 Session `index.html`，exact `@main` 可以通过既有 workspace 工具直接编辑整份
HTML/CSS/JavaScript、组织嵌套元素并承担全局协调和空间布局。ordinary sub-agent 默认在一次任务中
集中编辑一个互不重叠的辅助或元素网页，再由 `@main` 集成；不得并发 patch 共享 `index.html`。

这项“一个 sub-agent 负责一个元素”的关系是动态 TaskContract / prompt 约定，不是新的永久
Agent 类型、硬编码递归层级、Element ownership、CapabilityLease 或权限模型。

## 当前事实与目标状态

### 当前已经存在

- 从 Intatis 导入的 macOS Chat / Code / Cowork、SwiftUI harness、`CoworkViewModel`、
  `Orchestrator`、FIFO scheduler、AgentKernel、MessageBus/Mediator、Goal/WorkTask、
  PermissionEngine、EventLog、ArtifactStore 与 session lifecycle；
- 用户可见 macOS/iOS GUI 品牌 `Ekagium`；内部 target、bundle identity、配置与数据路径仍以
  `Intatis` 为主；
- 迁移前 Ekagium 的 Chromium/CEF 本地资产，以及只读的 CEF 白画布历史文档快照。
- 方案一最小原型：Cowork Session 启动在 fresh 七事件 bootstrap 后创建
  `.egakium/canvas/<SessionID>/index.html`；exact `@main` root prompt 获得该精确相对路径并可用现有
  file/patch + permission 链直接编辑；Cowork 内容 header 可打开 exact SessionID 的独立 Canvas 窗口；
- 当前 Canvas 窗口恢复同一 Session 的 primary workspace bookmark，只读取已初始化文件，以无持久
  Web 数据且阻断网络请求的薄 `WKWebView` 预览，并轮询文件变化自动刷新；它不创建第二套
  CoworkViewModel、runtime、EventLog 或权限控制面。

### 用户已经确认、仍待实现

- macOS Ekagium 的主要工作方式基于 Cowork，而不是以普通 Chat 或 Code harness 为产品中心；
- 最终产品形态中，现有 conversation-first Cowork harness 移到右侧侧边栏，业务逻辑保持不变；
- 中央主要内容区变为 HTML/DOM 空间画布；
- 临时开发阶段先保留现有 Cowork harness 独立窗口，并增加一个独立 Canvas 调试窗口；两者绑定
  同一个 exact Cowork Session 和同一套 session-scoped runtime，不形成两个 App、两个 Session 或
  两套 Cowork 控制面；
- 正式 CEF BrowserView、Helper、内部 scheme/origin/bridge、sandbox、签名和公证闭环；
- 稳定 ElementID、layout/revision/event/projection schema，以及按元素独立 HTML 小网页的完整宿主闭环；
- `@main` 决定元素创建、位置、大小、层级、空间关系与 sub-agent 委派；
- sub-agent 按本次任务提示编辑指定元素网页，不并发修改一份共享巨型 HTML；
- Canvas 与 Cowork harness 只通过窄、结构化的选择、定位、刷新、布局和上下文事件连接。

### 不得提前宣称

当前源码已经接入 Session Canvas 初始化、`@main` 直编路径提示、独立 Canvas 窗口和定向测试；但
`CoworkCanvasWindow` 只是 `WKWebView` 调试适配层，不是正式 CEF CanvasHost。源码仍没有 CEF
BrowserView/Helper 接线、正式 ElementID/layout/event schema 或 native bridge。迁移前 CEF 原型和
保留的 `.deps/` / `build/` 也不能作为这些待实现能力已经存在的证据。

## 产品布局合同

macOS Ekagium 的目标主视图为：

```text
┌──────────────────────────────────────────────────────────────┐
│                       Ekagium Cowork Session                  │
├───────────────────────────────────────┬──────────────────────┤
│                                       │                      │
│                                       │  现有 Cowork harness │
│                                       │                      │
│       Session-owned HTML Canvas       │  conversation        │
│                                       │  composer            │
│       independent HTML elements       │  agents/tasks/goal   │
│                                       │  permissions/status  │
│                                       │                      │
├───────────────────────────────────────┴──────────────────────┤
│          canvas/session/selection/viewport 辅助状态            │
└──────────────────────────────────────────────────────────────┘
```

- Canvas 是主要工作成果与空间组织表面；
- 右侧 harness 是用户向 `@main` 下达意图、查看执行状态和处理权限的控制面；
- 对话记录不替代 Canvas，Canvas 也不重新实现 Cowork 的消息、任务或权限系统；
- Chat/Code 可继续作为导入基线中的既有能力，但 Ekagium 新主工作流以 Cowork + Canvas 为中心；
- iOS 继续保持 Chat-only 结构性子集，当前目标不把 CEF、Canvas 或本地 Cowork 引入 iOS。

## 临时双窗口实施路线（非最终产品形态）

为降低第一阶段 UI 改造量并隔离 Canvas/CEF 调试问题，用户确认先采用以下阶段性拓扑：

```text
同一个 Ekagium macOS 进程
└── exact Cowork Session / single session-scoped runtime authority
    ├── Existing Cowork Harness Window
    │   └── conversation / composer / agents / tasks / permissions
    └── Canvas Debug Window
        └── CoworkCanvasWindow / WKWebView preview / Session index.html
```

这里的“两个窗口”只描述暂时的展示容器，不表示两套业务系统：

- 现有 Cowork harness 窗口在该阶段尽量原样保留，不先做右侧窄栏、父级 split view 或最终产品壳；
- Canvas 调试窗口通过稳定的 exact SessionID 关联同一 Session，只承载 Canvas 的加载、渲染、交互和
  调试表面；
- 不得为 Canvas 窗口再创建一套 CoworkViewModel、Orchestrator、scheduler、MessageBus、permission
  queue、EventLog、AppSessionRuntime 或 Session authority；
- Canvas 是 Session-owned，不是 window-owned。空白 Canvas 的幂等初始化由 `CoworkViewModel` 的
  Session 启动/bootstrap 路径触发；窗口只调用 `existingCanvas` 打开既有文件，不能由“打开窗口”
  临时创建；关闭、重开或重建 Canvas 窗口也不能重置、删除或复制 Canvas；
- Canvas 窗口关闭不得停止 Cowork Session；现有 Command-W、最后窗口关闭、Command-Q、删除 Session
  和冷启动恢复合同继续生效；
- CanvasHost 必须设计成可复用的内容宿主，独立窗口只是一层临时 wrapper。后续合窗应当只是把同一个
  CanvasHost 嵌入中央区域，并把同一个现有 harness 放到右侧，而不是重写两条链路；
- Canvas/harness 的跨窗口连接仍只能使用稳定 SessionID/CanvasID/ElementID 和窄结构化事件，不能依赖
  当前 key window、显示标题或隐式全局 selection 推断 Session authority。

采用这条路线的目的，是先分别验证渲染生命周期、内部资源加载、Canvas 恢复、Session 路由和元素
隔离，再承担 harness 窄栏适配与最终单窗口布局的回归成本。它是**已确认的临时调试路线**，不是新的
最终产品形态，也不是将 Ekagium 拆成两个独立 App 的决定。当前最小双窗口路线已经实现；CEF 替换、
完整元素隔离和最终合窗仍未实现。

## 现有 Cowork harness 的复用边界

目标组合在概念上等价于：

```swift
HStack(spacing: 0) {
    EkagiumCanvasHost(sessionID: sessionID)
    ExistingCoworkHarnessView(sessionID: sessionID)
        .frame(width: sidebarWidth)
}
```

实际类型与文件位置以实现时的当前源码为准；上例只表达所有权边界。

### 必须保持不变的 harness 语义

- `CoworkViewModel` 的提交、恢复、Retry、Cancel、Stop、Goal 与 WorkTask 语义；
- `SubmittedIntentStore`、outbox、FIFO admission 与 exact `@main` inference binding；
- Orchestrator、scheduler、AgentLoop、MessageBus/Mediator 与 agent roster；
- composer 编辑/Send/Stop/附件/语音行为；
- conversation projection、分页、agent conversation selection 与 historical roster；
- permission reviewer、人工/自动 permission flow 与 permission UI；
- EventLog、session projection、runtime manager、Command-W/Command-Q 和删除 session 的生命周期；
- 现有工具、CapabilityLease、WorkspaceLease、PathConfinement 与 durable execution 边界。

### 允许的 UI 组合变化

- 在现有 harness 外增加 Canvas + sidebar 的父级布局；
- 为右侧容器设置宽度、最小宽度、分隔线、展开/收起或用户可调宽度；
- 为窄侧栏做必要的纯展示适配，但不得改变业务协议或运行时语义；
- 把 Canvas 当前选择作为额外、显式的用户上下文交给 `@main`；
- 根据 durable Agent/Task 状态在 Canvas 元素外框显示低信息量的工作状态。

不得为了接入 Canvas 重写一套 conversation、composer、agent roster、task graph、permission queue
或 session runtime。

## Session 与 Canvas 初始化合同

初始产品合同为 **一个 Cowork Session 对应一张 Canvas**。

新 Session 的目标顺序：

```text
用户创建 Cowork Session
  -> 现有 Cowork settings-first 七事件 bootstrap 成功
  -> 宿主执行独立、幂等、无模型请求的 Canvas 初始化
  -> 从固定版本模板创建空白 Session Canvas
  -> 当前 WKWebView 调试预览（未来 CEF/CanvasHost）加载该 Canvas
  -> 临时阶段由独立 Canvas 窗口显示；最终阶段嵌入中央区域
  -> 现有 Cowork harness 在同一 Session 上继续显示
  -> 用户首次 Send 后才允许发生正常 provider 工作
```

约束：

- 不改变 fresh Cowork 已冻结的 exact 七事件 bootstrap 顺序和含义；
- Canvas 初始化不得在七事件中插入额外 agent/lease/settings 事实；
- Canvas 初始化由宿主确定性完成，不让模型临时生成基础 `index.html`；
- 当前固定 workspace-relative 路径为
  `.egakium/canvas/<SessionID>/index.html`；同一 primary workspace 中的多个 Session 由 SessionID
  命名空间隔离；
- 初始化不调用 provider，不产生 assistant 消息，也不启动 sub-agent；
- Retry/replay 必须幂等，不能为同一 Session 创建两张不同主画布；
- 冷启动只恢复 Canvas 与 Cowork durable 状态，不自动恢复 provider 执行；
- Session 切换、Command-W 或关闭最后窗口不删除 Canvas，也不隐式 stop Cowork runtime；
- 当前 Canvas 是用户 primary workspace 内的工作成果；删除 Session 继续沿用现有 exact-session
  drain/remove fence，但原型不会擅自删除 workspace 内的 Canvas 目录；未来如需自动清理必须单独
  冻结所有权和可恢复语义；
- 原型没有增加 Canvas EventLog 事件或独立 durable schema。元素/revision/layout/event schema 仍需
  单独冻结，不能把当前最后一份 HTML 扩张为整个 Cowork Session 的唯一事实源。

## 主画布与元素网页边界

### Session 主画布

方案一中，主画布是“宿主初始化、exact `@main` 直接编辑”的 Session 页面。宿主负责首次创建有效
HTML 模板和渲染安全边界；`@main` 负责后续完整 HTML/CSS/JavaScript、嵌套元素和空间布局。当前
模板提供空白 `#canvas`、`.egakium-element` 与本地 iframe 基础样式。

未来主画布可逐步承担：

- 空白空间、viewport、平移和缩放；
- 元素容器、选择、高亮、拖动、resize、层级与分组；
- 加载独立元素网页；
- 把窄、类型化的 Canvas 事件交给原生宿主；
- 在 Session 恢复后重建当前元素与布局投影。

共享主画布只属于 exact `@main` 的协调编辑范围，不属于 ordinary sub-agent 的默认交付物。不得安排
多个 Agent 并发 patch 它；这是一条 prompt/scheduling 纪律，不是永久 owner class 或 lease。

### 独立元素网页

每个 Canvas 元素是一份独立 HTML 小网页。概念目录为：

```text
<primary-workspace>/.egakium/canvas/<SessionID>/
├── index.html                  # host-created once; exact @main directly editable
├── canvas-runtime.js           # optional/future supporting file
├── canvas.css                  # optional/future supporting file
├── layout.json                 # conceptual future projection; exact schema 待冻结
└── elements/
    ├── element-001/
    │   ├── index.html
    │   ├── style.css
    │   ├── script.js
    │   └── assets/
    ├── element-002/
    │   └── ...
    └── element-003/
        └── ...
```

其中 `index.html` 路径已经由当前原型实现；其余文件和目录只是产品边界示意，不是已经存在的
schema。方案一允许 `@main` 先直接把多个语义元素嵌套在 `index.html` 中，也允许它引用同一 Session
目录下的独立本地 iframe document。独立元素文件仍是多人协作时的推荐隔离方式，不是 v0 原型的
硬件级限制。

元素可以承载文本、报告、卡片、表格、图表、看板、幻灯片、交互控件或其他 HTML/CSS/JS
表达。正式 Element/layout schema 落地后，元素内容与空间布局应保持分离：

```text
Element content:  独立网页内部 HTML/CSS/JS/Assets
Element layout:   x / y / width / height / z-index / group / relation
```

- sub-agent 编辑元素内容；
- `@main` 协调整体布局；
- 稳定 Element/layout schema 落地后，调整位置应尽量不要求重写元素 HTML；
- ordinary sub-agent 编辑独立元素内容时不应覆盖布局或其他元素；
- 不允许多个 Agent 把所有结果并发 patch 到同一 Session `index.html`。

### 渲染组合

当前原型在单一 `WKWebView` 中加载 Session 本地 `index.html`，read-access root 只给该 Session
Canvas 目录，并用 WebKit content rule 阻断 `http/https/ws/wss/ftp` 请求；默认模板另带 CSP。该层是
可替换的调试预览，不是最终 CEF 发行证明。

正式方向是在一个主 CEF BrowserView 中渲染 Session Canvas，并让每个元素容器加载一份
独立 document，优先使用受控 `iframe`/独立内部 URL，而不是每个元素启动一个 CEF Browser 或
Chromium 进程：

```html
<div class="egakium-element" data-element-id="element-001">
  <iframe src="egakium://session/.../elements/element-001/index.html"></iframe>
</div>
```

最终内部 scheme、origin、iframe sandbox flags、CSP 与资源映射必须在实现前冻结；上例不是已经
注册的 URL 协议。元素外框拥有布局与选择交互，iframe/document 内部拥有元素自己的内容和行为。

## `@main` 空间协调者合同

exact `@main` 仍是现有 Cowork stable root identity，不新增永久 `CanvasCoordinator` Agent 类型。
其 model-facing coordinator prompt 在 Ekagium Canvas 可用时追加空间合同：

- 你是当前 Session 的总体协调者；
- 你的精确 workspace-relative 画布入口是
  `.egakium/canvas/<SessionID>/index.html`，宿主已经创建基础文件；
- Canvas 相关请求应先读取该文件，再通过 authoritative workspace file/patch 工具和正常权限链直接
  编辑完整 HTML/CSS/JavaScript；
- 用户通过右侧 Cowork harness 向你说明目标；
- 你必须检查当前 Canvas、元素目录、选择和任务状态；
- 你决定需要创建哪些元素以及它们的位置、大小、层级和空间关系；
- 当工作量、并行性或专业能力确实有收益时，你把元素内部内容作为明确任务委派给合适的 ordinary
  sub-agent；
- 可以直接实现简单嵌套元素；需要并行或专长时，把 ordinary sub-agent 分配到互不重叠的辅助/元素
  文件，等待成功 ToolResult 后由你在共享 `index.html` 中集成或引用；
- 创建 Agent、创建任务、委派任务等因果依赖必须遵循现有 ToolResult round 边界；
- sub-agent 完成后，你检查整体结果、处理跨元素关系并按需重新布局；
- 你不能因“协调者”身份绕过 authoritative tool list、lease、permission 或 workspace 边界；
- 你仍不得自我认证 Goal 完成，也不得把普通 final 文本伪装成 durable run close。

当前没有专用 Canvas mutation tool；`@main` 使用既有 workspace file/patch 工具，因此继续经过当前
ToolRegistry、CapabilityLease、WorkspaceLease、PermissionEngine 与 durable tool execution。未来若
增加专用 Canvas tool，它也必须通过现有 ToolRegistry、
CapabilityLease、PermissionEngine、durable tool execution 和 EventLog 约束，不能成为隐藏的 UI
直写后门。

## sub-agent 元素编辑合同

ordinary sub-agent 继续使用现有 Agent identity、TaskContract、workspace/capability lease、scheduler
和 mailbox。一次元素任务的 scoped prompt/context 至少包含：

```text
当前 Session / Canvas 的安全摘要
本次 ElementID
该元素网页的 exact workspace-relative path 或 Artifact reference
本次 objective / roleHint / expectedDeliverable
允许修改的内容范围
相关元素的有界摘要或显式共享 artifacts
完成后的验证与回报方式
```

默认提示约定：

- 本次集中编辑指定元素的小网页；
- 不修改共享 Session `index.html`，除非当前任务由 `@main` 明确改派且不存在并发编辑者；
- 不修改其他元素；
- 不自行移动、resize 或重排整张画布；
- 不把其他元素复制进自己的 HTML；
- 完成后向 `@main` 返回结果、验证和需要的后续协调。

这不是永久硬约束：

- 同一个 Agent 可以按先后任务编辑多个元素；
- 同一个元素可以在后续任务中交给另一个 Agent；
- `@main` 可以在失败、复核或专业能力变化时重新委派；
- 产品不新增永久 `ElementAgent` / `leaf` 类型；
- 产品不把 AgentID 写成 Element 的永久 owner；
- 产品不新增只为绑定 Agent/Element 的 ElementLease；
- 同一元素默认一次只安排一个主动编辑任务，是 prompt/scheduling 纪律而非角色继承规则。

现有 CapabilityLease、WorkspaceLease、权限与路径边界继续真实执行；“提示词约定”只描述任务分工，
不能削弱安全控制。

## Canvas 与 harness 的窄连接

Canvas 不应读取完整 harness 内部状态，harness 也不应因为 Canvas 产生第二套事件总线。目标连接仅限
稳定 ID 驱动的结构化操作，例如：

```text
Canvas -> host/harness
  canvasSelectionChanged(ElementID?)
  canvasElementActivated(ElementID)
  canvasViewportChanged(...)
  userRequestedElementContext(ElementID)

host/@main -> Canvas
  focusCanvasElement(ElementID)
  refreshCanvasElement(ElementID, revision)
  updateCanvasLayout(ElementID, frame)
  reflectElementTaskStatus(ElementID, status)
```

上述名称是语义示意，不是已冻结协议。正式 schema 必须使用稳定 SessionID/CanvasID/ElementID、
版本、来源与必要 correlation，不能从显示标题或 HTML 内容反推 identity。

## 持久化与恢复方向

当前 EventLog 继续是 Session runtime canonical truth，`session.json` 继续只是可重建 projection，
ArtifactStore 继续保存大块内容。Canvas 接入不得建立一个会覆盖上述事实的第二套 Session authority。

当前原型已经明确：Canvas 工作副本位于 primary workspace 的
`.egakium/canvas/<SessionID>/index.html`，宿主只做 no-overwrite 初始化，后续文件内容由现有
workspace 工具链编辑；该 HTML 不是 EventLog canonical Session truth。仍需明确并记录：

- CanvasID 与 Cowork SessionID 的稳定对应；
- ElementID、element revision 与 layout revision；
- 元素 HTML/CSS/JS/assets 与 ArtifactStore blob 是否需要受控副本关系；
- Canvas/element mutation 的 durable event 与 projection 关系；
- 原子写入、冲突、失败、取消、恢复和删除语义；
- 旧 Session 没有 Canvas 事实时的 additive migration；
- unknown future canvas event 与旧程序的 fail-closed 行为。

不得把“最后一份 HTML 文件”单独当作整个 Cowork Session 的唯一事实源；也不得在没有 schema、
版本和迁移合同前随意扩充现有 EventLog Envelope。

## CEF、Web 与原生安全边界

- `Chromium/` 继续只是历史验证/排障资产，不得恢复 `Chromium.app --app=<URL>` 产品链；
- `.deps/` 中的官方 CEF 资产可在独立集成任务中重新核对版本、校验值、provenance 与 bundle 规则后
  复用；不得直接修改其发行文件，也不得把旧 `build/` 生成物当作产品源码或唯一可重现依赖；
- 正式方向使用 Ekagium 自有 macOS app 生命周期内嵌 CEF，不魔改 Chrome UI、不使用
  `content_shell`、不自建 Chromium fork；
- 当前 `WKWebView` 仅用于最小调试闭环：non-persistent website data store、Session 目录 read access、
  top-level scheme allowlist 和 content-rule network deny。它不能冒充 CEF sandbox/Helper/签名证据；
- 页面、元素和 Agent 生成的 JavaScript 不得直接获得任意文件、进程、Shell、credential 或 native
  bridge 权限；
- bridge 必须异步、白名单化、可版本化，并验证 origin、SessionID、ElementID、参数和权限；
- 内部资源需要稳定 origin、CSP、路径校验和 element document 隔离；
- CEF sandbox/进程隔离、Helper、Hardened Runtime、nested code signing 与公证必须按直接分发合同
  重新验证；旧 `USE_SANDBOX=OFF` ad-hoc 原型不能成为发行证据；
- 不做 Mac App Store 不代表可以取消 CEF/Web 隔离或当前 Intatis 权限/lease/Seatbelt 安全链。

## 明确非目标

- 不重写或替换现有 Cowork harness；
- 不为 Canvas 创建第二套 Orchestrator、scheduler、AgentLoop、MessageBus、permission queue 或 EventLog；
- 不把临时双窗口解释成两个 Session、两个 App 或两套 runtime，也不把 Canvas 内容所有权绑定到
  Canvas 窗口的打开/关闭；
- 不把临时 Canvas 调试窗口提前冻结为最终产品布局；
- 不让多个 Agent 并发修改一个 Session 的共享 `index.html`；exact `@main` 可以按方案一直接编辑它，
  ordinary sub-agent 应使用互不重叠的辅助/元素路径再交由 `@main` 集成；
- 不把“一个 Agent 编辑一个元素”硬编码成永久 Agent hierarchy、owner field 或 capability inheritance；
- 不让 `@main` 同步递归调用 sub-agent AgentLoop；
- 不让 Canvas/CEF 绕过 ToolRegistry、PermissionEngine、WorkspaceLease 或 SecretScanner；
- 不恢复完整 Chromium、`chrome --app`、Content embedder 或旧 CEF 独立 App 作为当前产品壳；
- 不在本目标中批量重命名 Intatis target/module/bundle/config/data/protocol identity；
- 不把 Canvas/Cowork 引入 iOS；
- 不自动执行旧 `docs/NEXT_TARGET.md` 中的 Intatis v0.48 公证发布任务。

## 推荐实现顺序

除非用户另行调整，后续代码工作按最小可验证纵向切片推进：

1. **已完成原型**：保持现有 Cowork harness 窗口，增加按 exact SessionID 绑定的独立 Canvas 调试窗口；
2. **已完成原型**：建立一个 Session 一份确定性 `index.html` 的宿主初始化、旧 Session additive
   初始化、no-overwrite 恢复和 exact `@main` 直编提示；
3. 用正式单一主 CEF BrowserView 替换当前 WKWebView 调试适配层，并完成内部资源、生命周期和空白
   画布验证；
4. 冻结 ElementID、独立元素网页、layout projection 与 iframe/document 隔离；
5. 先完成宿主创建、移动、resize、选择、刷新单个元素的无模型闭环；
6. 扩充当前 `@main` 精确入口路径 prompt/context；只有真实需要时再增加专用 Canvas tools；
7. 用现有 spawn/delegate/task flow 把单个 ElementID + 页面范围交给 ordinary sub-agent；
8. 完成多元素并行、冲突、恢复、安全、性能、签名和公证验证；
9. 核心链路稳定后，再把同一个 CanvasHost 嵌入中央区域，并将现有 harness 组合成右侧侧边栏。

每一步都必须保留前述七事件 bootstrap、EventLog、权限、lifecycle、iOS 与 direct-distribution 边界。

## 首批验收方向

后续实现至少需要证明：

- 新建两个 Cowork Session 会得到两张互不串线的空白画布；
- 临时 Canvas 窗口与现有 harness 窗口能同时绑定同一 exact Session，且不会产生第二套 runtime；
- Session 切换、窗口关闭/重开和多窗口选择不会新建、重置或串线 Canvas/ElementID/harness 状态；
- 现有 harness 的 Send/Stop/Retry/Goal/Task/Agent/permission 与恢复语义没有变化；
- Canvas 初始化不调用 provider，不增加第八个 bootstrap agent/lease event；
- 两个独立元素网页可同时显示，修改其中一个不会改动另一个或主画布；
- `@main` 可创建/布局两个元素，并在成功取得 sub-agent ToolResult 后分别委派；
- sub-agent prompt 默认只编辑指定元素，但 reassignment 和顺序接手仍可发生；
- CEF/element JS 不能直接访问本地文件、Shell、credential 或未授权 bridge；
- Command-W、Command-Q、删除 Session、崩溃重开与 historical replay 继续满足现有生命周期合同；
- CanvasHost 不依赖临时 Window wrapper，可在后续最终布局中原样嵌入；
- iOS target graph 仍不含 Cowork、CEF、Tools 或本地 workspace Agent。

实际测试命令和 fixture 应在相应实现任务中写入 `docs/TESTING.md`，不能用本文的目标矩阵冒充
已经通过的验证证据。

## 仍需在实现前冻结的细节

- Canvas durable schema、Element revision 与 ArtifactStore/workspace 的精确所有权；
- CEF 在 SwiftPM/XcodeGen 中的 target、wrapper、bundle resource 和 Helper 接线；
- 主画布内部 scheme、origin、CSP、iframe sandbox 与 bridge schema；
- Canvas viewport、选中、拖拽、resize、z-order、group 的第一版交互范围；
- Canvas selection 如何以有界、非伪 authority 的方式进入 `@main` context；
- Canvas mutation 哪些是 host-local UI 操作，哪些是 model-facing tool call；
- generated HTML/JS 的资源预算、隔离、错误恢复和性能上限；
- CEF 版本是否沿用保留资产中的版本，或作为独立升级任务重新固定。

这些细节标记为“需要后续确认/冻结”，不影响本文件已经确定的产品形态和职责边界。
