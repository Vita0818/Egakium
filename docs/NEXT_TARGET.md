# NEXT_TARGET

文档状态：Ekagium 单一活跃产品目标；方案一最小双窗口原型已实现，CEF/元素模型/最终合窗待实现
确认日期：2026-08-15
产品基线：v0.2（build 49）
内部兼容边界：仍为 Intatis target/module/config/data identity
完整产品合同：`docs/EGAKIUM_CANVAS_COWORK.md`

## 目标：建立 Cowork-first / Canvas-first 的 macOS Ekagium 工作台

把当前 conversation-first 的 macOS Cowork 产品面组合为：中央每个 Cowork Session 独立的
HTML/DOM Canvas，右侧直接复用现有 Cowork harness。宿主先创建每个 Session 的基础
`index.html`，exact `@main` 可以直接编辑整份页面并负责全局空间布局、协调和委派；需要并行时，
ordinary sub-agent 默认在一次任务中编辑一个互不重叠的辅助/元素网页，再由 `@main` 集成。

这不是重写 Cowork harness，也不是恢复旧独立 CEF App。现有 Swift-native Cowork runtime、
CoworkViewModel、Orchestrator、scheduler、MessageBus、PermissionEngine、EventLog、Goal/WorkTask、
exact inference binding 和 session lifecycle 继续作为产品底座。

为先压低 UI 改造与联合调试成本，第一阶段暂不直接实现上述最终单窗口布局。现有 Cowork harness
先保留在自己的窗口，另增加一个独立 Canvas 调试窗口；两个窗口必须绑定同一个 exact SessionID，
共享同一套 session-scoped runtime/authority。该分窗是临时实施路线，不是最终产品形态。

## 已确认产品合同

1. macOS Ekagium 的新主工作流基于 Cowork。
2. 现有 Cowork conversation harness 放到右侧侧边栏，只做必要 UI 组合/窄栏适配。
3. 中央主要内容区是一张 HTML/DOM 空白画布。
4. 每个新 Cowork Session 自动、确定性、无 provider 请求地初始化一份独立 Canvas。
5. Session `index.html` 由宿主从固定模板首次创建，之后 exact `@main` 可以通过既有 workspace
   file/patch + permission 链直接编辑整页；ordinary sub-agent 不得并发修改共享入口。
6. 每个 Canvas 内容元素是一份独立 HTML 小网页，可带自己的 CSS、JavaScript 和 assets。
7. 元素内容与位置、尺寸、层级、分组等 layout 数据分离。
8. exact `@main` 通过追加 prompt/context 负责元素规划、布局、协调和委派。
9. ordinary sub-agent 默认在当次 TaskContract 中集中编辑一个指定 ElementID 的网页。
10. 第 9 点只是 prompt/task 分工，不是永久 Agent class、Element owner、ElementLease、硬编码递归
    hierarchy 或 capability inheritance；允许顺序接手和重新委派。
11. Canvas 与 harness 只通过稳定 ID 驱动的窄结构化选择、定位、刷新、布局和状态事件连接。
12. 当前目标只进入 macOS；iOS 继续保持 Chat-only 真子集。
13. 临时开发阶段先将现有 harness 窗口与 Canvas 调试窗口分开；分窗不得创建第二个 Cowork Session、
    AppSessionRuntime 或控制面，Canvas 也不得因窗口打开/关闭而创建、重置或停止。

## 最小实施顺序

### A. 临时双窗口调试壳（最小原型已完成，非最终产品布局）

- 保持现有 macOS Cowork harness 窗口及其 View/ViewModel 行为，不先做右侧窄栏适配；
- 已增加薄 `CoworkCanvasWindow`，通过 exact SessionID 恢复同一 primary workspace bookmark 并加载
  该 Session 已存在的 Canvas；
- 两个窗口共享同一个 session-scoped runtime/authority，不复制 conversation、composer、Orchestrator、
  scheduler、MessageBus、permission queue、EventLog 或 AppSessionRuntime；
- 保持 Send/Stop/Retry/Goal/Tasks/Agents/permission/model selection 和 runtime 行为；
- 当前预览 host 不依赖 key-window 状态或显示标题，后续渲染层必须可替换并嵌入最终中央区域；
- 关闭或重开 Canvas 窗口不得创建、重置、删除或停止 Session Canvas。

### B. Session-owned 空白 Canvas（最小原型已完成）

- 在既有 fresh Cowork 七事件 bootstrap 成功后执行独立 Canvas 初始化；
- 从固定、版本化模板创建空白 Canvas，不让模型生成基础 `index.html`；
- 当前固定路径为 `.egakium/canvas/<SessionID>/index.html`，创建使用 no-overwrite 发布；已存在的
  `@main` 编辑不得在恢复或重开时被覆盖；
- 初始化幂等且不调用 provider，不创建 Agent，不插入第八个 bootstrap agent/lease event；
- Session 切换、多窗口、Command-W、Command-Q、删除和冷启动遵循现有 exact-session lifecycle；
- 旧 Session 没有 Canvas 时由同一 Cowork Session 启动路径 additive 初始化，不添加伪造历史事件；
- Canvas 窗口只打开既有文件，不承担创建 authority。

### C. CEF 主画布闭环

- 在当前 Ekagium macOS app 生命周期内嵌一个主 CEF BrowserView；
- 加载 Session 自己的 host-created、exact `@main`-editable Canvas document；
- 不恢复 `Chromium.app --app`、完整 Chromium UI、`content_shell`、Content embedder 或旧独立 CEF App；
- 冻结内部 scheme/origin、CSP、资源映射、Helper lifecycle、sandbox/进程隔离、签名和公证边界；
- 可在独立 CEF 接入任务中核对版本、校验值、provenance 和 bundle 规则后复用 `.deps/` 中的官方
  CEF 资产；不得直接修改其发行文件，也不得把旧 `build/` 生成物当作产品源码或唯一可重现依赖。

### D. 独立元素网页

- 冻结 CanvasID、ElementID、element revision、layout revision 和 storage ownership；
- 主 CEF Canvas 通过受控 iframe/独立 document URL 加载每个元素网页；
- 一个元素的 HTML/CSS/JS 不污染另一个元素或主画布；
- 宿主先完成无模型的 create/move/resize/select/refresh 单元素闭环；
- 不让多个 Agent 并发修改同一个主 HTML 或同一个元素网页。

### E. `@main` 与 sub-agent 接线（入口直编提示已完成，元素委派待实现）

- 已只给 exact `@main` root 的既有 coordinator prompt 追加精确
  `.egakium/canvas/<SessionID>/index.html`、直编和并发隔离合同；ordinary worker 不收到该路径；
- Canvas tools 若成为 model-facing tool，继续经过 ToolRegistry、CapabilityLease、PermissionEngine、
  durable execution 和 EventLog；
- 正式 ElementID schema 落地后，`@main` 先创建/取得 ElementID，再在后续 ToolResult round 使用已经
  attached 的 worker 委派；当前原型可由 `@main` 直接创建嵌套 HTML 或独立本地 iframe 文件；
- sub-agent TaskContract/context 携带 exact ElementID、页面范围、交付物和验证方式；
- 不新增永久 ElementAgent 类型，不修改普通 worker 的默认协调能力，不嵌套 AgentLoop。

### F. 恢复、安全与性能收口

- 冻结 Canvas/Element additive event 与 projection schema；
- 明确 ArtifactStore 与 workspace 文件的 canonical/working-copy 关系；
- 验证 crash/replay、unknown future event、取消、失败、原子提交和冲突处理；
- 对 generated HTML/JS 建立 origin、CSP、iframe sandbox、bridge allowlist 和资源预算；
- 验证多元素并行、长 Session、CEF/Helper 退出、Hardened Runtime、签名与公证。

### G. 合并为最终产品布局

- 只在独立 Canvas 窗口已经验证 Session 路由、CEF 生命周期、空白画布恢复和元素隔离后进行；
- 把同一个可复用 CanvasHost 放入 Cowork Session 中央区域，并将同一个现有 harness 组合到右侧；
- 再处理 sidebar 宽度、最小宽度、展开/收起、可访问性和窄栏纯展示适配；
- 合窗不能重建 Session/runtime、改变 Canvas identity，或引入第二套 conversation/permission/lifecycle。

## 不得改动的 Cowork harness 边界

- 不重写 `CoworkViewModel` submission/outbox/retry/cancel/Goal/WorkTask 逻辑；
- 不改变 Orchestrator、FIFO scheduler、TaskGraph、MessageBus/Mediator 或 AgentLoop；
- 不改变 permission reviewer、PermissionEngine、manual/automatic mode 或 permission projection；
- 不改变 exact per-agent inference binding、main/reviewer/GoalVerifier 隔离；
- 不改变 EventLog canonical truth、session.json projection、workspace bookmark 或 ArtifactStore 安全边界；
- 不改变 AppSessionRuntimeManager、Command-W/Command-Q、删除 Session 和冷启动只 replay 的合同；
- 不改变现有 composer、conversation paging、agent thread selection 和 historical roster 语义；
- 不创建第二套 Canvas 专用对话、任务、Agent roster、权限队列或 session runtime。
- 不让临时 Canvas 窗口的 open/close 状态成为 Canvas 是否存在、是否初始化或是否继续运行的 authority。

## 第一批可验收结果

完成该目标至少必须提供以下证据：

1. 新建两个 Cowork Session，分别获得互不串线的空白 HTML Canvas（core 定向测试已证明同 workspace
   的两个 Session 使用不同路径；真实 GUI 双 Session 手动测试待做）。
2. 临时 Canvas 窗口与现有 harness 窗口可同时绑定同一个 exact Session，且只有一套 session runtime。
3. Canvas 初始化没有 provider 请求，fresh Cowork 七事件 bootstrap 仍精确保持七事件（源码路径与
   构建已核对，完整 GUI/EventLog fixture 待补）。
4. 两个独立 HTML 元素可同时显示；修改一个不会改变另一个或主画布。
5. `@main` 能创建、定位两个元素，并在成功 ToolResult 后分别委派给已 attached sub-agent。
6. sub-agent 默认只编辑指定元素，但可由后续任务重新委派，不存在永久 Element owner。
7. Session 切换、Canvas 窗口关闭/重开、多窗口选择、Command-W、Command-Q、删除和 crash/reopen
   不造成 Canvas/harness 串线、Canvas 重置或隐式 provider resume。
8. CEF/element JavaScript 无法直接访问本地文件、Shell、credential 或未授权 native bridge。
9. macOS Debug 构建、受影响 SwiftPM/Cowork/UI tests 和专用 Canvas/CEF tests 通过（当前
   `IntatisMac` arm64 Debug、5 个 Canvas store tests 与 exact `@main` prompt test 已通过；CEF tests
   尚不存在）。
10. iOS target closure 继续不包含 Cowork、Tools、CEF 或本地 workspace Agent。

具体测试命令和最近证据只在实现时写入 `docs/TESTING.md`；本文件中的标准不是已通过声明。

## 明确非目标

- 不继续执行被本文件替换的 Intatis v0.48 公证 release gate；分发缺口仍保留在当前状态文档，
  但不是本轮产品目标。
- 不批量重命名 Intatis target/module/bundle/config/data/protocol identity。
- 不重新设计现有 Cowork harness。
- 不把临时双窗口调试拓扑当作最终产品布局或拆成两个独立 App。
- 不把一个 Agent 对一个元素硬编码成权限或永久角色系统。
- 不让多个 Agent 共享并发编辑同一 `index.html`；exact `@main` 按方案一直接编辑不违反本条。
- 不恢复完整 Chromium 或旧 `chrome --app` 实验链。
- 不在本目标中给 iOS 增加 Cowork、CEF 或本地 Agent。
- 不在缺少真实安全、签名、公证和 Gatekeeper 证据时把 CEF 集成描述为可发行。

## 当前进度

- 已完成原型：Session-scoped no-overwrite `index.html` 初始化与恢复、exact `@main` 直编 prompt、
  exact SessionID Canvas Window、网络阻断 WKWebView 调试预览、文件变化刷新、Core/prompt 测试与
  `IntatisMac` arm64 Debug 构建。
- 尚未完成：真实 GUI 双 Session/窗口生命周期手测、正式 CEF 接线、ElementID/layout/event/bridge
  schema、多元素/委派闭环、最终中央 Canvas + 右侧 harness 合窗、签名/公证发行验证。

下一次业务实现应从 CEF 接线前的人工原型验收或“最小实施顺序”中的 C 开始；不得因本文件存在而
自动下载/升级 CEF、签名、公证或发布。
