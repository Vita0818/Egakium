# Egakium 文档索引（Egakium 业务基线）

当前产品基线：**v0.4**（build 50）
最近核对：2026-08-18

这个索引区分“当前规范”和“历史证据”。版本、产品状态或下一步判断只允许从当前规范
读取；带旧版本号的历史文件保留用于解释迁移和兼容性，不能覆盖当前源码。

当前业务源码仍是从 Egakium 导入的 SwiftPM/XcodeGen 基线；用户已确认 Egakium 的当前产品层为
Cowork-first / Canvas-first macOS 工作台。方案一的 Session Canvas 初始化、exact `@main` 直编提示和
单一 Cowork 窗口内的左 CanvasHost / 右原 harness 拼接已经实现；此前独立 Canvas scene/action
已按用户 2026-08-16 的纠正移除。macOS 主 sidebar 当前只展示 Cowork；Chat/Code 入口只是隐藏，
对应实现、runtime 与数据仍保留。2026-08-17 曾加入的 WK provisional direct-card runtime 已在
2026-08-18 CEF cutover 中删除；source `#canvas`/card/relative iframe contract 保留并由 CEF/CSS 直接
渲染，不再有宿主注入 drag/resize/sessionStorage。所有 child page 统一到一份 host-authored generic template；每个 Cowork AgentInvocation
中，成功的 ordinary spawn 会在 child exact workspace 下自动获得一份 fresh real file，并把 validated
ElementID/path/version 贯穿 durable spawn events、ToolResult、`list_agents` 与 child prompt；read-only
仍不可编辑，manual/legacy attach 使用 prompt fallback。正式 CEF-only renderer 已实现；durable
Element/layout/bridge schema 仍未实现。
产品合同见 `EGAKIUM_CANVAS_COWORK.md`，迁移边界见 `EGAKIUM_MIGRATION.md`。

2026-08-18 用户最终确立 dependency-first / no-fallback：已有同能力且可采用的外部依赖时必须直接
集成，禁止自研 adapter、shim、parallel/preview backend 或临时兜底；接入受阻必须报告 blocker。
官方 CEF 是 Canvas 唯一接受 renderer；当前 product target 已真实链接、打包并运行 pinned official
CEF ARM64 Framework/Helpers，WKWebView/WebKit Canvas 与 fallback 已删除。CEF 不可用时构建失败或
Canvas 明确 unavailable。权威规则见 `OPEN_SOURCE_REUSE.md`。

## 当前规范

| 文档 | 权威范围 |
|---|---|
| `EGAKIUM_MIGRATION.md` | Egakium 工作树导入、Egakium 保留资产、展示层换名与验证边界 |
| `EGAKIUM_CANVAS_COWORK.md` | 已确认的 Cowork-first / Canvas-first 合同、单窗口 CEF Canvas、provisional source card 与待实现 durable 元素边界 |
| `VERSIONING.md` | 产品版本与 build number 的唯一治理规则 |
| `CURRENT_STATE.md` | 当前能力、验证状态、已知缺口 |
| `PROJECT_MAP.md` | 当前目录、target、入口、关键文件和脚本 |
| `ARCHITECTURE.md` | 当前运行时链路、数据模型、安全与平台边界 |
| `CHAT_HOSTED_SEARCH.md` | 当前模型自主托管搜索、接入点适配、静默不搜索与实现边界 |
| `DO_NOT_BREAK.md` | 协议、持久化、权限、工具与 UI 回归禁区 |
| `TESTING.md` | 当前测试矩阵、命令和最近一次证据 |
| `MACOS_DISTRIBUTION.md` | Developer ID 直接分发合同 |
| `OPEN_SOURCE_REUSE.md` | dependency-first/no-fallback、第三方源码、prompt、依赖和 NOTICE 准入 |
| `COWORK_PRINCIPLES.md` | 当前 Cowork/AgentKernel 编排原则 |
| `PER_AGENT_INFERENCE_PROFILES.md` | per-agent exact inference binding 契约 |
| `CURRENT_UI_COLOR_SYSTEM.md` | 当前 Apple 原生表面与 Liquid Glass 规范 |
| `NEXT_TARGET.md` | 唯一活跃目标；不保存已完成里程碑流水账 |

根 `README.md` 是 Egakium 产品入口；根 `ARCHITECTURE.md` 仅为兼容链接，架构正文只
维护在 `docs/ARCHITECTURE.md`。`AGENTS.md` 及 Claude/Gemini shims 是操作政策，不表达产品版本。

## 操作政策与供应链资料

下列文件不是产品状态页，不应复制当前版本号：

- 根目录与 `docs/` 下的 `AGENTS.md`、`CLAUDE.md`、`GEMINI.md`：agent 操作规则或继承入口；
- `NOTICE.md`、`ThirdPartyNotices/` 和依赖附带的 README/LICENSE：来源与许可证证据；
- `.agents/skills/` 下的文档：项目级 skill 说明；
- `codex-report/`、`claude-report/`、`gemini-report/`：按日期冻结的执行报告。

这些资料保留自己的规则、依赖版本或历史日期。不得为追齐 Egakium marketing version 而
批量替换其中的版本数字。

## 历史设计与验证

以下文件冻结旧阶段，不再作为当前事实源：

- `COWORK_AGENT_ARCHITECTURE.md`
- `COWORK_AGENT_INVOCATION_MODEL.md`
- `COWORK_CURRENT_FINDINGS.md`
- `COWORK_MIGRATION_PLAN.md`
- `COWORK_TASK_CONTEXT_MODEL.md`
- `COWORK_V0_10_SMOKE.md`
- `COWORK_V0_10_STATUS.md`
- `UI_COLOR_SYSTEM.md`
- 根 `design-qa.md`
- `codex-report/`、`claude-report/`、`gemini-report/` 中的 dated reports

历史文档里的版本、测试数量、截图路径和环境结果只能说明当时发生过什么。若它们与
当前源码、工程配置或上方当前规范冲突，以源码/配置和当前规范为准，并记录冲突。

## 维护纪律

- 外部 capability 选择先遵守 Vitemis canonical `/Users/vita/Vitemis/docs/DEPENDENCY_POLICY.md`，再按
  `OPEN_SOURCE_REUSE.md` 做项目准入；活跃文档不得把自研替代层、preview backend 或“以后替换”写成
  可接受路线。
- 当前状态文档保持摘要化；完成事项留在 Git 历史和 dated report，不继续无限追加。
- `NEXT_TARGET.md` 只保留一个正在推进的目标，完成后删除或替换。
- `EGAKIUM_CANVAS_COWORK.md` 记录已确认目标合同；实现完成度只能从源码、`CURRENT_STATE.md` 和
  验证证据判断，不能从目标文档反推。
- `egakium-cef-baseline/` 是迁移前只读历史快照，不随当前产品合同改写。
- `TESTING.md` 保存当前命令和最新证据；旧性能数字或事故细节留在报告中。
- 不批量替换依赖、协议、schema、历史里程碑中的版本号。
- 修改产品版本后必须运行 `scripts/check-version-consistency.sh`。
- `EGAKIUM_*.md` 文件名、仓库物理目录 `Egakium/` 与 `.egakium/` Canvas 路径都是当前
  Egakium identity；不得再建立另一套兼容路径。
