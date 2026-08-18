# AGENTS.md

本文是 docs 级 Codex 入口。项目事实和项目专属要求应写在项目自己的根入口或项目内文档中。

开始工作前必须先读：

1. `/Users/vita/Vitemis/AGENTS.md`
2. `../AGENTS.md`（如果存在）

基本规则：

- Codex 是主工作者，只能按用户任务和项目边界修改文件。
- 已完成的持久性改动必须及时回写到相关项目文档；若无需更新文档，最终报告说明原因。
- 当前 `NEXT_TARGET.md` 记录用户确认的 Cowork-first / Canvas-first Egakium 产品目标；完整合同见
  `EGAKIUM_CANVAS_COWORK.md`。方案一 Session Canvas 与单一 Cowork 窗口内的左 CEF CanvasHost /
  右原 harness 拼接已经进入源码；WKWebView、WebKit 注入和 renderer fallback 已删除。此前独立
  Canvas scene/action 已按
  用户 2026-08-16 的纠正移除。macOS 主 sidebar 当前只展示 Cowork；Chat/Code 入口仅隐藏，底层
  enum、View/ViewModel、runtime、history 与配置仍保留。2026-08-17 WK 路径曾加入 provisional DOM
  element-card runtime；该 renderer-specific 交互已随 CEF cutover 删除，当前只保留 source
  HTML/CSS element-card contract，尚无 durable ElementID/layout/event schema。子页面只有一份
  host-authored generic element template；每个
  成功的 ordinary `spawn_agent` 会在 child exact workspace root 下自动创建 fresh no-overwrite 文件，
  并把 ElementID/path/template version 写入 spawn events、ToolResult、`list_agents` 与 child prompt；
  read-only child 仍不能编辑，manual/legacy attach 才使用 identity-free prompt fallback。`@main` 必须
  等待成功 ToolResult 才能集成 card，spawn 不修改共享 `index.html`。正式 CEF-only renderer 已接入；
  完整元素持久化/bridge 仍未实现。不得因文档存在而自动升级 CEF、签名、公证、发布或扩大范围。
- 2026-08-18 用户最终确立项目级 dependency-first / no-fallback 规则，Vitemis canonical 为
  `/Users/vita/Vitemis/docs/DEPENDENCY_POLICY.md`，项目具体合同见 `OPEN_SOURCE_REUSE.md`：已有同能力
  且可采用的外部依赖时必须直接集成，禁止自研 adapter、shim、
  parallel backend、preview backend 或临时兜底；接入受阻必须报告 blocker，不得换技术顶替。对
  Canvas，官方 CEF 是唯一接受 renderer；当前 target 已直接使用 pinned CEF，且不存在 WKWebView
  Canvas 或 fallback。后续不得恢复第二 renderer 或把最薄 CEF binding 扩张成自研浏览器 abstraction。
- `egakium-cef-baseline/` 是业务基线导入前的 CEF 文档历史快照；除非用户明确要求修订历史，
  不得修改其中内容。迁移事实以 `EGAKIUM_MIGRATION.md` 为准。
- `../OpenSource/` 当前由根 `.gitmodules` 登记为 26 个 shallow gitlink；它们是独立上游研究
  checkout，不是父仓库普通源码。不得递归 stage/commit/push、拍平或改变指针，除非用户明确点名
  对应父仓库 gitlink 或子仓库操作。
- Git 版本控制默认只读；编辑、整理、修复、验证或准备工作都不等于提交请求。只有用户当前任务明文要求具体 Git 操作时，Codex 才可按要求执行对应的非破坏性 Git 操作。若用户要求提交，只提交当前 Git root 中与本任务相关的文件；不得递归进入、暂存、提交或推送子仓库、submodule、nested Git repo 或依赖 checkout。
- 不得读取、打印、摘要或写入密钥、token、证书、Keychain、`.env` 等敏感信息。
- 若与项目根入口冲突，采用更严格的规则。

报告要求：

- Codex 报告只能写入 `../codex-report/`。
- 报告文件名必须采用 `MM_DD_YY-HH_MM-xxxx.md`，例如 `06_30_26-21_45-permission-audit.md`。
- 报告正文必须先写 `MODEL_CHECK_RESULT`。除非项目根入口另有硬性模型门禁，模型字段只用于记录，不因模型版本号不匹配而停止。
- 报告建议包含：`MODEL_CHECK_RESULT`、`PATH_CHECK_RESULT`、`FILES_WRITTEN`、`SUMMARY`、`VALIDATION_RESULT`、`UNCERTAINTIES`、`NEXT_RECOMMENDED_ACTION`。
