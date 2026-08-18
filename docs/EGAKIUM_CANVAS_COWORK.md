# EGAKIUM_CANVAS_COWORK

文档状态：用户已确认的 Egakium 产品合同；CEF-only renderer 已接入，WKWebView 替代路线已删除
确认日期：2026-08-18
当前业务基线：Egakium v0.4（build 50；源码与技术 identity 使用 Egakium SwiftPM/XcodeGen 基线）
适用范围：macOS Egakium 主产品面、Cowork UI 组合、Canvas/Element 模型与 Agent 协作边界

## 一句话结论

Egakium 是一个 **Cowork-first、Canvas-first** 的多 Agent 空间工作台：中央是每个
Cowork Session 独立初始化的 HTML/DOM 画布，右侧直接复用现有 Cowork harness。宿主只负责从
固定模板首次创建 Session `index.html`，exact `@main` 可以通过既有 workspace 工具直接编辑整份
HTML/CSS/JavaScript、组织嵌套元素并承担全局协调和空间布局。ordinary sub-agent 默认在一次任务中
集中编辑一个互不重叠的辅助或元素网页，再由 `@main` 集成；不得并发 patch 共享 `index.html`。

这项“一个 sub-agent 负责一个元素”的关系是动态 TaskContract / prompt 约定，不是新的永久
Agent 类型、硬编码递归层级、Element ownership、CapabilityLease 或权限模型。

## Dependency-first / no-fallback 最终决定

2026-08-18 用户最终明确：已有同能力且可采用的外部依赖时，必须直接集成，不允许自研 adapter、
shim、parallel/preview backend 或临时兜底。接入受阻应明确停止并报告 blocker，不能以“先做原型、
以后替换”推导替代实现权限。项目级权威合同见 `docs/OPEN_SOURCE_REUSE.md`。

对本合同，官方 CEF 是唯一接受的 Canvas 网页 renderer。当前 product target 已直接接入 pinned
official CEF ARM64 Framework、官方 wrapper/external pump、五个 sandbox Helpers、AppKit child browser、
Session-rooted scheme 与 init/shutdown lifecycle。WKWebView、WKContentWorld、WKNavigationDelegate、
WebKit file loader、DOM injection、metadata monitor 与 fallback 已删除。CEF 不可用时构建失败或 Canvas
明确 unavailable/fail closed；不得重新增加另一 renderer、adapter 或切换层。

## 当前事实与目标状态

### 当前已经存在

- 当前 macOS Chat / Code / Cowork、SwiftUI harness、`CoworkViewModel`、
  `Orchestrator`、FIFO scheduler、AgentKernel、MessageBus/Mediator、Goal/WorkTask、
  PermissionEngine、EventLog、ArtifactStore 与 session lifecycle；
- macOS/iOS GUI、内部 target、bundle identity、配置与数据路径统一使用 `Egakium`；
- 业务基线导入前已有的 Chromium/CEF 本地资产，以及只读的 CEF 白画布历史文档快照。
- renderer-independent 基础：Cowork Session 启动在 fresh 七事件 bootstrap 后创建
  `.egakium/canvas/<SessionID>/index.html`；exact `@main` root prompt 获得该精确相对路径并可用现有
  file/patch + permission 链直接编辑；
- 主 Cowork detail 已使用原生 `HSplitView` 原样左右拼接：左侧可复用 `CoworkCanvasHost` 直接读取同一
  `CoworkViewModel.canvasDocument`，右侧为参数和业务行为未改的现有 `CoworkShell`。两侧共用同一个
  exact Session、VM、runtime、EventLog 和权限控制面；
- 当前源码只有这一处 Canvas presentation，内嵌 host 只使用 `EgakiumCEFView`；2026-08-16 用户在
  实际打开后明确纠正此前双窗口路线，
  独立 Canvas scene、`Open Canvas` 动作、窗口 value/resolver/model/view wrapper 均已移除；打开或恢复
  Cowork 时必须同时看到左 Canvas 与右 harness；
- 2026-08-17 曾把实施顺序调整为先改造 WK 主画布、再继续 CEF；该实现已删除。
  `SessionCanvasRuntime` 曾建立
  provisional DOM contract v1：`#canvas` 的每个 direct `.egakium-element` 使用 stable-safe
  `data-element-id`、title、x/y/width/height 和同 Session 目录的相对 iframe 表示一张子 HTML 卡片；
  WebKit content world 曾提供 drag/resize/keyboard/sessionStorage 与 metadata refresh；这些源码和
  测试已移除。当前只保留 source `#canvas`/card/relative iframe shape，模板 CSS 由 CEF 直接渲染，
  宿主不注入交互 runtime；
- CEF closure 已实现：exact official
  `151.3.17+gf059e67+chromium-151.0.7922.138_macosarm64` pin、archive hash gate、official wrapper/
  external pump、five sandbox Helpers、versioned Framework/Resources/notices、per-view memory-only request
  context、strict `egakium://canvas` Session resource factory、network/popup deny 与 orderly shutdown；
- 同日用户决定所有子元素共用一份固定模板。`SessionCanvasElementTemplate` v1 是唯一
  host-authored child-document seed；不含 AgentID、ElementID、SessionID、路径或 outer-card layout，
  成功的 ordinary `spawn_agent` 会在 child exact workspace root 下获得一个 host-chosen
  `CanvasElementID` 与 fresh no-overwrite real file；同一 descriptor 进入 durable spawn events、
  ToolResult、`list_agents` 和 child trusted prompt。manual/legacy attach worker 才在 prompt 中获得
  identity-free fallback copy；`@main` 不重复注入完整 HTML，也不预造 ID/path。host provisioning 不
  授予 agent write authority，后续编辑仍由 WorkspaceLease/CapabilityLease 决定；
- macOS 主 sidebar 当前只展示 Cowork，初始 selection 也是 Cowork。Chat/Code 的 enum case、detail
  branch、View/ViewModel、runtime、session/history 与配置继续编译和保留，只隐藏可见入口。

### 用户已经确认、仍待实现

- Developer ID nested signing、公证、staple/Gatekeeper 的真实发行执行（build 脚本已接线，尚未提交）；
- durable CanvasID/ElementID、layout/revision/event/projection schema，以及按元素独立 HTML 小网页的
  持久化/恢复闭环；当前 `data-element-id` 只是 provisional DOM identity；
- `@main` 决定元素创建、位置、大小、层级、空间关系与 sub-agent 委派；
- sub-agent 按本次任务提示编辑指定元素网页，不并发修改一份共享巨型 HTML；
- Canvas 与 Cowork harness 只通过窄、结构化的选择、定位、刷新、布局和上下文事件连接。

### 不得提前宣称

当前源码已经接入 Session Canvas 初始化、`@main` 直编路径提示、单窗口左右拼接、renderer-independent
Element/Agent 文件合同和正式 CEF-only renderer。不得宣称已经有 durable ElementID/layout/event
projection、native bridge、用户 drag/resize persistence 或 provider-driven 多元素 App E2E；Debug CEF
证据也不等于 Developer ID 公证发行完成。
“新 sub-agent 获得模板”当前确实表示 successful ordinary `spawn_agent` 已创建一个 workspace-local
generic element file 和 provisional `CanvasElementID`，并持久记录 spawn-scoped descriptor；但它不会
自动创建/修改主 Canvas Card，不是 durable layout/bridge schema，也不建立永久 Agent↔Element
mapping。read-only child 仍不能编辑，agent recycle 也不会删除这份可重新委派的文件。
迁移前 CEF 原型和保留的 `.deps/` / `build/` 不能直接证明当前 target 已接线，但它们是正式 CEF
任务必须优先核对的官方依赖/provenance 资产；不得绕开后另写 renderer。

## 产品布局合同

macOS Egakium 的目标主视图为：

```text
┌──────────────────────────────────────────────────────────────┐
│                       Egakium Cowork Session                  │
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
- Chat/Code 继续作为导入基线中的既有能力，但 macOS 主 sidebar 当前隐藏其入口；Egakium 可见的
  新主工作流只展示 Cowork + Canvas，恢复入口时不得重建或迁移底层实现；
- iOS 继续保持 Chat-only 结构性子集，当前目标不把 CEF、Canvas 或本地 Cowork 引入 iOS。

## 当前单窗口原样左右拼接

2026-08-16 用户确认当前只做两个现有表面的原样左右拼接，并在实际看到 Canvas-only 窗口后明确
纠正：只保留一个 Cowork 窗口，不保留独立 Canvas 调试/备用入口。实际拓扑为：

```text
同一个 Egakium macOS 进程
└── exact Cowork Session / single session-scoped runtime authority
    └── Main Cowork detail / native HSplitView
        ├── CoworkCanvasHost / Session index.html
        └── existing CoworkShell / conversation / composer / status
```

主界面 split 只组合 presentation，不改变业务系统：

- 左侧 host 直接消费现有 VM 已初始化的 `SessionCanvasDocument`；右侧 `CoworkShell` 的现有参数、
  composer、conversation、Agents/Goal/Tasks/permission、Send/Stop/Retry 与 lifecycle 行为保持不变；
- 父级只设置两侧最小/理想宽度并使用系统可拖拽分隔线；本轮没有新增 drawer、overlay、折叠策略、
  Activity 面板、第二份 harness 或新的窄栏业务模式；
- App scene 不注册 Canvas 专用 `WindowGroup`，Cowork header 不提供 `Open Canvas`，也不存在按
  SessionID 恢复 workspace 的独立窗口 resolver。macOS state restoration 因而没有 Canvas-only scene
  可以恢复；
- Canvas 是 Session-owned，不是 window-owned。空白 Canvas 的幂等初始化由 `CoworkViewModel` 的
  Session 启动/bootstrap 路径触发；内嵌 host 不能由 presentation 临时创建 Canvas，组合视图的关闭、
  重开或重建也不能重置、删除或复制 Canvas；
- 现有 Command-W、最后窗口关闭、Command-Q、删除 Session 和冷启动恢复合同继续生效；
- `CoworkCanvasHost` 是主 Cowork detail 内的可复用内容宿主，不依赖独立 Window wrapper；
- Canvas/harness 的连接只能使用稳定 SessionID/CanvasID/ElementID 和窄结构化事件，不能依赖当前
  key window、显示标题或隐式全局 selection 推断 Session authority。

当前左右拼接只完成 UI 容器层，CEF 替换和完整元素隔离仍未实现。需要渲染调试时应在这个唯一组合
窗口内完成，不得重新引入会把 harness 隐藏掉的 Canvas-only 产品入口。

## 现有 Cowork harness 的复用边界

当前组合在概念上等价于：

```swift
HSplitView {
    CoworkCanvasHost(document: vm.canvasDocument, errorMessage: vm.canvasInitializationError)
    CoworkShell(/* existing arguments and callbacks */)
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
  -> CoworkCanvasHost / 正式 CEF AppKit child browser 加载该 Canvas
  -> 主 Cowork detail 左侧显示 CanvasHost，右侧显示现有 CoworkShell
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
模板提供 `#canvas` element-container、空态、provisional `.egakium-element` markup 示例与本地
iframe 基础样式；CEF 直接渲染 source HTML/CSS，宿主不注入 DOM runtime。

当前 provisional DOM v1 已承担：

- 浏览器原生滚动的网格空间与 source-owned direct element container；
- 通过同 Session 目录相对 iframe 加载独立元素网页；
- source `data-x/y/width/height` 的 CEF/CSS card placement；
- `sandbox="allow-scripts"` 的 child document boundary。

当前没有 host-owned selection/bring-to-front/drag/resize/keyboard、layout override 或 automatic file
monitor。未来增加这些能力不得重建自研 adapter。

未来 durable 层仍需承担：

- Canvas-native viewport 平移/缩放和 group/relation；
- 把窄、类型化的 Canvas 事件交给原生宿主；
- 在 Session 恢复后重建当前元素与布局投影。

共享主画布只属于 exact `@main` 的协调编辑范围，不属于 ordinary sub-agent 的默认交付物。不得安排
多个 Agent 并发 patch 它；这是一条 prompt/scheduling 纪律，不是永久 owner class 或 lease。

### 独立元素网页

每个 Canvas 元素是一份独立 HTML 小网页。概念目录为：

```text
<primary-workspace>/.egakium/canvas/<SessionID>/
├── index.html                  # host-created once; exact @main directly editable
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

其中 `index.html` 由宿主初始化；successful ordinary spawn 会由宿主为该 admission 创建一个 fresh
`elements/<ElementID>/index.html`，其他子文件仍可由 `@main`/ordinary sub-agent 通过既有 workspace
工具创建。`layout.json` 仍只是未来 projection 示意。card CSS 在 host-created source template 中，
由 CEF 直接解释；没有 injected host JavaScript。方案一仍允许 `@main` 直接把简单语义内容放入
`index.html`；多人协作时优先引用独立本地 iframe document。

provisional DOM v1 的 source shape 为：

```html
<article class="egakium-element"
         data-element-id="element-001"
         data-element-title="Element title"
         data-x="64" data-y="64"
         data-width="420" data-height="300">
  <iframe src="elements/element-001/index.html"
          title="Element title"
          sandbox="allow-scripts"></iframe>
</article>
```

- card 必须是 `#canvas` 的 direct child；
- `data-element-id` 当前只接受 1–128 个 ASCII 字母、数字、`_`、`-`，同一页面重复 ID 会被禁用；
- x/y/width/height 是 `index.html` 中的 source layout；z 可用 `data-z` 可选声明；
- 没有 host-generated chrome/content/resize DOM 或用户 override；source markup 是当前页面 authority；
- child iframe 当前收窄到 `sandbox="allow-scripts"`，父页面/child assets 由同一 strict
  `egakium://canvas` Session origin 提供；当前没有 native bridge。

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

当前源码在一个官方 CEF AppKit child browser 中渲染 Session Canvas，并让每个元素容器加载一份
独立 document，优先使用受控 `iframe`/独立内部 URL，而不是每个元素启动一个 CEF Browser 或
Chromium 进程：

```html
<div class="egakium-element" data-element-id="element-001">
  <iframe src="egakium://canvas/elements/element-001/index.html"
          sandbox="allow-scripts"></iframe>
</div>
```

`egakium://canvas` 已注册为 standard/secure/display-isolated custom scheme；每个 view 的 factory 只
读取 exact Session root 内 non-symlink regular files，且 request context 不持久化。CSP/iframe sandbox
仍由 source document 限制。元素外框拥有 source layout，iframe/document 拥有元素内部内容和行为；
当前没有宿主 selection/drag/resize 或 bridge。

## `@main` 空间协调者合同

exact `@main` 仍是现有 Cowork stable root identity，不新增永久 `CanvasCoordinator` Agent 类型。
其 model-facing coordinator prompt 在 Egakium Canvas 可用时追加空间合同：

- 你是当前 Session 的总体协调者；
- 你的精确 workspace-relative 画布入口是
  `.egakium/canvas/<SessionID>/index.html`，宿主已经创建基础文件；
- Canvas 相关请求应先读取该文件，再通过 authoritative workspace file/patch 工具和正常权限链直接
  编辑完整 HTML/CSS/JavaScript；
- 每份 child HTML 默认使用上面的 direct card + source-layout attributes + relative sandboxed iframe
  shape；不要在页面里再实现与 host 冲突的第二套 drag/resize runtime，也不要把 Web storage 或
  runtime DOM mutation 写成 durable layout；
- 用户通过右侧 Cowork harness 向你说明目标；
- 你必须检查当前 Canvas、元素目录、选择和任务状态；
- 你决定需要创建哪些元素以及它们的位置、大小、层级和空间关系；
- 当工作量、并行性或专业能力确实有收益时，你把元素内部内容作为明确任务委派给合适的 ordinary
  sub-agent；
- 为新元素创建 ordinary sub-agent 时，不要预造 ElementID/path；宿主会在 spawn commit 时选择并
  no-overwrite 创建。只有 worker 需要修改文件时才为 `spawn_agent` 明确请求 `read_write`。必须等待
  成功 ToolResult 返回 `canvas_element_id` / `canvas_element_path` / `canvas_template_version`，再在下一
  tool-call round 通过 TaskContract/`delegate_task` 交付该 exact path 和结果要求；
- 新 worker 的 actual invocation 会自动收到自己的真实 element descriptor；不要把模板全文复制进
  TaskContract，也不要把 spawn-time association 写成 Element owner。read-only spawn 也有文件但无
  修改权限；
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
和 mailbox。successful ordinary spawn 先在其 exact workspace root 建立以下
`SessionCanvasElementTemplate.html` 的 fresh real copy，并在 trusted system prompt 中提供 validated
ElementID/path/version；manual/legacy attach invocation 才直接嵌入同一 identity-free template fallback：

```html
<html data-egakium-element-template="1">
  ...
  <main id="element" data-egakium-element-document="1">
    ...
    <section id="content">...</section>
  </main>
</html>
```

该模板是 content-only child page：

- outer Canvas 继续拥有 card chrome、ElementID、x/y/width/height、selection、drag/resize；
- child template 只拥有自己的内部 HTML/CSS/JavaScript/local assets，并以 `#element` / `#content`
  作为稳定集成边界；
- 模板 CSP 默认 `connect-src 'none'`、`frame-src 'none'`、无 remote resource；
- spawned worker 的文件是真实 workspace resource，但 host creation 不授予 agent write capability；
  manual/legacy prompt fallback 仍不是文件或权限；
- spawned worker 使用 host-returned exact path，不得自己选择共享入口或另造 sibling path；
- descriptor path 始终相对 child 的 exact WorkspaceLease root。child 与主 Canvas 同根时，`@main` 可在
  成功 ToolResult 后转换为同 Session `elements/...` iframe；若 child 是 distinct workspace，spawn 不
  会偷偷授予第二个 root 或让 `@main` 跨 lease 读取，必须走后续明确授权/媒介/集成路径；
- exact destination 已存在时必须先读并保留，绝不能用“fresh template”覆盖已有工作；
- spawn admission 在 EventLog batch 前发布文件；append failure 必须先用 complete-known replay 判断
  exact batch 是否已因 WAL/lost-ack durable。已提交则恢复成功；只有证明 descriptor fact 未提交时才
  compensation 删除仍为 exact 原始 template 的目录，无法证明时保留并 fail closed。成功后
  recycle/detach 不删除文件。
- 该顺序优先保证“durable spawned agent 一定已有文件”，但进程若恰好在 file publish 与 EventLog
  append 之间崩溃，仍可能留下无 descriptor 引用的 generic orphan directory。当前没有安全的自动 GC；
  restore 不得仅凭目录扫描删除它，后续需要 versioned orphan/recovery policy 才能清理。

一次元素任务的 scoped prompt/context 至少包含：

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

旧 WK provisional runtime 曾在 DOM 内 dispatch `egakium:canvas-selection-change` /
`egakium:canvas-layout-change` 并暴露 `EgakiumCanvas` helper；该 runtime 与这些 API 已删除。当前没有
Canvas↔harness native bridge 或 EventLog writer，上述语义示意不得被当成已冻结协议。

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

当前没有宿主提供的 drag/resize layout override；source `index.html` 的 x/y/width/height 是页面
authority。未来用户 layout 必须先冻结 durable layout/revision/event 合同，不能借用 CEF profile、
Web storage 或注入 DOM 状态冒充 crash recovery/跨窗口同步。

## CEF、Web 与原生安全边界

- `Chromium/` 继续只是历史验证/排障资产，不得恢复 `Chromium.app --app=<URL>` 产品链；
- `.deps/cef` 中 exact pinned official distribution 已由 `config/cef.cmake` 和 build scripts 正式消费；
  不得直接修改发行文件、绕过 hash gate 或把旧 `build/xcode` 生成物当作 canonical dependency；
- 当前实现使用 Egakium 自有 macOS app 生命周期内嵌 CEF，不魔改 Chrome UI、不使用
  `content_shell`、不自建 Chromium fork；
- WKWebView/WebKit Canvas、content world/navigation/lifecycle 和 fallback 已删除，不得恢复；
- CEF 缺失、版本/hash 不匹配、Helper/resource/bundle 不完整或初始化失败时必须 fail closed/明确
  Canvas unavailable，不得改用 WKWebView、截图渲染或外部 Chromium 窗口；
- 页面、元素和 Agent 生成的 JavaScript 不得直接获得任意文件、进程、Shell、credential 或 native
  bridge 权限；
- 当前没有 native bridge；未来 bridge 必须异步、白名单化、可版本化，并验证 origin、SessionID、
  ElementID、参数和权限；
- 内部资源现使用 stable `egakium://canvas` origin、CSP、canonical root/path/symlink/regular-file 校验与
  element document 隔离；
- CEF sandbox/进程隔离、Helper、Hardened Runtime、nested code signing 与公证必须按直接分发合同
  重新验证；旧 `USE_SANDBOX=OFF` ad-hoc 原型不能成为发行证据；
- 不做 Mac App Store 不代表可以取消 CEF/Web 隔离或当前 Egakium 权限/lease/Seatbelt 安全链。

## 明确非目标

- 不重写或替换现有 Cowork harness；
- 不为 Canvas 创建第二套 Orchestrator、scheduler、AgentLoop、MessageBus、permission queue 或 EventLog；
- 不重新增加独立 Canvas scene/window、`Open Canvas` 动作、Canvas-only 调试/备用入口或第二套
  presentation；
- 不删除仅被隐藏入口的 Chat/Code enum、View/ViewModel、runtime、session/history、配置或协议；
- 不让多个 Agent 并发修改一个 Session 的共享 `index.html`；exact `@main` 可以按方案一直接编辑它，
  ordinary sub-agent 应使用互不重叠的辅助/元素路径再交由 `@main` 集成；
- 不把“一个 Agent 编辑一个元素”硬编码成永久 Agent hierarchy、owner field 或 capability inheritance；
- 不让 `@main` 同步递归调用 sub-agent AgentLoop；
- 不让 Canvas/CEF 绕过 ToolRegistry、PermissionEngine、WorkspaceLease 或 SecretScanner；
- 不恢复完整 Chromium、`chrome --app`、Content embedder 或旧 CEF 独立 App 作为当前产品壳；
- 不重新分裂已经统一的 Egakium target/module/bundle/config/data/protocol identity；
- 不把 Canvas/Cowork 引入 iOS；
- 不自动执行旧 `docs/NEXT_TARGET.md` 中的 Egakium v0.48 公证发布任务。

## 实现顺序与当前停点

前四步已完成；后续步骤只是已知缺口，不是自动获准的下一任务：

1. **已完成 renderer-independent 基础**：建立一个 Session 一份确定性 `index.html` 的宿主初始化、旧 Session additive
   初始化、no-overwrite 恢复和 exact `@main` 直编提示；
2. **已完成 UI 组合与入口纠正**：抽取可复用 `CoworkCanvasHost`，在 `CoworkSessionView` 中用原生
   水平 split 原样拼接左 Canvas 与右现有 `CoworkShell`；移除独立 Canvas scene/window/header action，
   保证用户打开的唯一 Cowork surface 同时包含两边；
3. **已完成 renderer-independent Element/Agent 合同**：固定唯一 generic child-document template，把 successful ordinary
   spawn 的 fresh file/ID、additive descriptor events、ToolResult/`list_agents`/prompt/replay、dispatch
   validation、lost-ack recovery 与 replay-proven compensation 接通；
4. **已完成 CEF-only cutover**：直接接入单一主 CEF child browser/Helpers，删除 WKWebView 与全部
   WebKit-specific fallback，并完成 pin/hash、资源 scheme、lifecycle、sandbox 与 ARM64 bundle 接线；
5. 冻结 durable CanvasID/ElementID、layout projection、origin/iframe document 隔离与 native bridge；
6. 让宿主的 create/move/resize/select/refresh 从 provisional DOM 行为升级为可恢复的单元素闭环；
7. 只有真实需要时再增加经现有权限/durable execution 链的专用 Canvas tools；
8. 用现有 spawn/delegate/task flow 把单个 ElementID + 页面范围交给 ordinary sub-agent；
9. 完成多元素并行、冲突、恢复、安全、性能、签名和公证验证。

每一步都必须保留前述七事件 bootstrap、EventLog、权限、lifecycle、iOS 与 direct-distribution 边界。
开始第 5 步或以后任一步前，必须先由用户确定 exact 范围和所采用的外部依赖；不得自行补回 DOM
adapter 或“临时交互层”。

## 首批验收方向

后续实现至少需要证明：

- 新建两个 Cowork Session 会得到两张互不串线的空白画布；
- 主界面左 Canvas 与右 harness 绑定同一 exact Session/VM/runtime，拖动分隔线不重建业务状态；
- 打开或恢复 Cowork 时只有一个组合窗口，并同时显示 Canvas 与 harness；不存在 Canvas-only scene、
  `Open Canvas` action 或可被系统恢复的独立 Canvas 窗口；
- Session 切换、窗口关闭/重开不会新建、重置或串线 Canvas/ElementID/harness 状态；
- 现有 harness 的 Send/Stop/Retry/Goal/Task/Agent/permission 与恢复语义没有变化；
- Canvas 初始化不调用 provider，不增加第八个 bootstrap agent/lease event；
- 两个独立元素网页可同时显示，修改其中一个不会改动另一个或主画布；
- `@main` 可创建/布局两个元素，并在成功取得 sub-agent ToolResult 后分别委派；
- sub-agent prompt 默认只编辑指定元素，但 reassignment 和顺序接手仍可发生；
- CEF/element JS 不能直接访问本地文件、Shell、credential 或未授权 bridge；
- Command-W、Command-Q、删除 Session、崩溃重开与 historical replay 继续满足现有生命周期合同；
- CanvasHost 不依赖 Window wrapper，内嵌 host 保持文件刷新和 Web 安全配置；
- iOS target graph 仍不含 Cowork、CEF、Tools 或本地 workspace Agent。

实际测试命令和 fixture 应在相应实现任务中写入 `docs/TESTING.md`，不能用本文的目标矩阵冒充
已经通过的验证证据。

## 仍需在实现前冻结的细节

- Canvas durable schema、Element revision 与 ArtifactStore/workspace 的精确所有权；
- CEF 在 SwiftPM/XcodeGen 中的 target、wrapper、bundle resource 和 Helper 接线；
- 主画布正式内部 scheme、origin、CSP、iframe sandbox 与 bridge schema；当前
  `sandbox="allow-scripts"` 只是 WK 原型的 provisional 最小值；
- durable Canvas viewport/selection/drag/resize/z-order/group 范围；当前 provisional v1 只包含
  scrollable grid、direct cards、selection/bring-to-front、drag、resize、keyboard move/resize，
  不包含 Canvas-native pan/zoom/group/relation 或跨重启布局；
- Canvas selection 如何以有界、非伪 authority 的方式进入 `@main` context；
- Canvas mutation 哪些是 host-local UI 操作，哪些是 model-facing tool call；
- generated HTML/JS 的资源预算、隔离、错误恢复和性能上限；
- CEF 版本是否沿用保留资产中的版本，或作为独立升级任务重新固定。

这些细节标记为“需要后续确认/冻结”，不影响本文件已经确定的产品形态和职责边界。
