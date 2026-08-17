# NEXT_TARGET

文档状态：Ekagium 单一活跃产品目标；方案一、可复用 CanvasHost 与原样左右拼接已实现，CEF/元素模型待实现
确认日期：2026-08-16
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

当前主 Cowork detail 已按用户 2026-08-16 的确认只做原样左右拼接：原生 `HSplitView` 左侧放
可复用 `CoworkCanvasHost`，右侧放现有 `CoworkShell`，共同消费同一个 exact Session 和
`CoworkViewModel`。用户在实际打开后进一步纠正：只保留这一个组合窗口；此前独立 Canvas scene、
window、header action 和 resolver/model 已移除，不能再作为调试/备用入口恢复。
macOS 主 sidebar 当前进一步只展示 Cowork 并默认落到 Cowork；Chat/Code 入口只隐藏，其 enum、detail、
View/ViewModel、runtime、session/history 和配置继续保留。

## 已确认产品合同

1. macOS Ekagium 的新主工作流基于 Cowork。
2. 现有 Cowork conversation harness 已原样放到右侧；本轮只做父级 split 组合，不改 harness 业务或
   另做窄栏模式。
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
13. 产品只允许一个组合 Cowork presentation；打开或恢复时必须同时显示左 Canvas 与右 harness，
    不得注册 Canvas-only WindowGroup、action 或可被系统恢复的独立 scene。
14. macOS 可见模式入口暂时只有 Cowork；Chat/Code 必须以 presentation visibility 隐藏，不得删除其
    业务实现、runtime、数据或恢复分支。

## 最小实施顺序

### A. 单组合窗口入口（纠正已完成）

- 只保留主 Cowork detail 的原生 `HSplitView`；左侧 Canvas 与右侧 harness 必须一起出现；
- App scene 不注册 value-driven Canvas Window，Cowork header 不提供 `Open Canvas`；
- sidebar mode items 只投影 Cowork，root 初始 selection 为 Cowork；Chat/Code case 与分支保留；
- 已移除 Canvas window value、primary-workspace resolver/model 和 window view wrapper，避免 macOS
  state restoration 打开 Canvas-only surface；
- 保持 Send/Stop/Retry/Goal/Tasks/Agents/permission/model selection 和 runtime 行为；
- `CoworkCanvasHost` 不依赖 key-window 状态或显示标题；后续渲染层必须在这个内嵌 host 边界内替换；
- 组合视图关闭或重开不得创建、重置、删除或停止 Session Canvas。

### B. Session-owned 空白 Canvas（最小原型已完成）

- 在既有 fresh Cowork 七事件 bootstrap 成功后执行独立 Canvas 初始化；
- 从固定、版本化模板创建空白 Canvas，不让模型生成基础 `index.html`；
- 当前固定路径为 `.egakium/canvas/<SessionID>/index.html`，创建使用 no-overwrite 发布；已存在的
  `@main` 编辑不得在恢复或重开时被覆盖；
- 初始化幂等且不调用 provider，不创建 Agent，不插入第八个 bootstrap agent/lease event；
- Session 切换、Command-W、Command-Q、删除和冷启动遵循现有 exact-session lifecycle；
- 旧 Session 没有 Canvas 时由同一 Cowork Session 启动路径 additive 初始化，不添加伪造历史事件；
- 内嵌 CanvasHost 只消费 VM 提供的既有文档，不承担创建 authority。

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

### G. 原样左右拼接（基础组合已完成）

- `CoworkSessionView` 已用原生 `HSplitView` 把同一个可复用 `CoworkCanvasHost` 放在左侧、把同一个
  现有 `CoworkShell` 放在右侧；两边直接使用同一个 VM，未重建 Session/runtime 或改变 Canvas identity；
- 独立 Canvas scene/window/header action 和 workspace bookmark resolver/window wrapper 已移除；
- 本轮只设置两侧最小/理想宽度，没有增加展开/收起、overlay、drawer、Activity 面板或新的窄栏适配；
- 后续 CEF 替换、元素模型和可访问性/视觉手测不得引入第二套 conversation/permission/lifecycle。

## 不得改动的 Cowork harness 边界

- 不重写 `CoworkViewModel` submission/outbox/retry/cancel/Goal/WorkTask 逻辑；
- 不改变 Orchestrator、FIFO scheduler、TaskGraph、MessageBus/Mediator 或 AgentLoop；
- 不改变 permission reviewer、PermissionEngine、manual/automatic mode 或 permission projection；
- 不改变 exact per-agent inference binding、main/reviewer/GoalVerifier 隔离；
- 不改变 EventLog canonical truth、session.json projection、workspace bookmark 或 ArtifactStore 安全边界；
- 不改变 AppSessionRuntimeManager、Command-W/Command-Q、删除 Session 和冷启动只 replay 的合同；
- 不改变现有 composer、conversation paging、agent thread selection 和 historical roster 语义；
- 不创建第二套 Canvas 专用对话、任务、Agent roster、权限队列或 session runtime。
- 不重新增加独立 Canvas WindowGroup、header action、window resolver 或 Canvas-only 调试/备用入口。

## 第一批可验收结果

完成该目标至少必须提供以下证据：

1. 新建两个 Cowork Session，分别获得互不串线的空白 HTML Canvas（core 定向测试已证明同 workspace
   的两个 Session 使用不同路径；真实 GUI 双 Session 手动测试待做）。
2. 主界面左 Canvas 与右现有 harness 绑定同一个 exact Session/VM/runtime；打开或恢复 Cowork 时
   只有这一个组合 surface，不存在 Canvas-only scene/action/window。
3. Canvas 初始化没有 provider 请求，fresh Cowork 七事件 bootstrap 仍精确保持七事件（源码路径与
   构建已核对，完整 GUI/EventLog fixture 待补）。
4. 两个独立 HTML 元素可同时显示；修改一个不会改变另一个或主画布。
5. `@main` 能创建、定位两个元素，并在成功 ToolResult 后分别委派给已 attached sub-agent。
6. sub-agent 默认只编辑指定元素，但可由后续任务重新委派，不存在永久 Element owner。
7. Session 切换、组合窗口关闭/重开、Command-W、Command-Q、删除和 crash/reopen
   不造成 Canvas/harness 串线、Canvas 重置或隐式 provider resume。
8. CEF/element JavaScript 无法直接访问本地文件、Shell、credential 或未授权 native bridge。
9. macOS Debug 构建、受影响 SwiftPM/Cowork/UI tests 和专用 Canvas/CEF tests 通过（当前
   `IntatisMac` arm64 Debug、6 个 Canvas store tests 与 exact `@main` prompt test 已通过；CEF tests
   尚不存在）。
10. iOS target closure 继续不包含 Cowork、Tools、CEF 或本地 workspace Agent。

具体测试命令和最近证据只在实现时写入 `docs/TESTING.md`；本文件中的标准不是已通过声明。

## 明确非目标

- 不继续执行被本文件替换的 Intatis v0.48 公证 release gate；分发缺口仍保留在当前状态文档，
  但不是本轮产品目标。
- 不批量重命名 Intatis target/module/bundle/config/data/protocol identity。
- 不重新设计现有 Cowork harness。
- 不重新引入独立 Canvas 调试/备用窗口或拆成两个独立 App。
- 不把一个 Agent 对一个元素硬编码成权限或永久角色系统。
- 不让多个 Agent 共享并发编辑同一 `index.html`；exact `@main` 按方案一直接编辑不违反本条。
- 不恢复完整 Chromium 或旧 `chrome --app` 实验链。
- 不在本目标中给 iOS 增加 Cowork、CEF 或本地 Agent。
- 不在缺少真实安全、签名、公证和 Gatekeeper 证据时把 CEF 集成描述为可发行。

## 当前进度

- 已完成原型：Session-scoped no-overwrite `index.html` 初始化与恢复、exact `@main` 直编 prompt、
  可复用 `CoworkCanvasHost`、唯一主界面左 Canvas/右原 `CoworkShell` 水平拼接、独立 Canvas 入口移除、
  网络阻断 WKWebView 预览、文件变化刷新、Core/prompt 测试与 `IntatisMac` arm64 Debug 构建。
- 尚未完成：真实 GUI 双 Session、分隔拖拽与窗口生命周期手测、正式 CEF 接线、
  ElementID/layout/event/bridge schema、多元素/委派闭环、签名/公证发行验证。

下一次业务实现应从当前单窗口左右拼接的人工原型验收或“最小实施顺序”中的 C 开始；不得因
本文件存在而自动下载/升级 CEF、签名、公证或发布。
