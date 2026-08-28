# Egakium 文档索引

当前产品基线：**v0.4**（build 50）
最近核对：2026-08-28

本索引区分当前规范与历史证据。2026-08-28 的实现来源 cutover 已删除仓内共享 Intatis snapshot；
Egakium 当前是直接依赖 `/Users/vita/Vitemis/Intatis` 的产品 overlay。任何旧文档中的
`Packages/Egakium*`、`Vendor/*` 或本地 AgentLoop/Orchestrator source path 都不能再作为当前目录事实，
其运行时语义现在由 sibling Intatis checkout 提供。

## 当前规范

| 文档 | 权威范围 |
|---|---|
| `INTATIS_RUNTIME_INTEGRATION.md` | 直接依赖、HostIdentity、Codex Runtime、snapshot 删除、验证与升级合同 |
| `EGAKIUM_MIGRATION.md` | Egakium identity hard cutover、数据/配置不可见边界 |
| `EGAKIUM_CANVAS_COWORK.md` | Cowork-first 单窗口、CEF Canvas、Session/element 产品合同 |
| `VERSIONING.md` | 产品版本与 build number 唯一治理规则 |
| `CURRENT_STATE.md` | 当前能力、源码/构建事实、验证状态与已知缺口 |
| `PROJECT_MAP.md` | 当前目录、target、入口、依赖、关键文件和脚本 |
| `ARCHITECTURE.md` | 当前运行时语义、安全、持久化和平台边界；详细 shared 语义由 Intatis 实现 |
| `DO_NOT_BREAK.md` | 身份、依赖、协议、权限、工具、Canvas 与 UI 回归禁区 |
| `OPEN_SOURCE_REUSE.md` | dependency-first/no-fallback、依赖与 NOTICE 准入 |
| `TESTING.md` | 当前测试矩阵、最近证据和未运行 gate |
| `MACOS_DISTRIBUTION.md` | Developer ID 直接分发、Codex Runtime/CEF bundle closure |
| `COWORK_PRINCIPLES.md` | Cowork 编排原则；共享实现位于 Intatis，Egakium 不 fork |
| `PER_AGENT_INFERENCE_PROFILES.md` | per-agent exact inference binding 契约 |
| `CURRENT_UI_COLOR_SYSTEM.md` | 当前 Apple 原生表面与视觉系统 |
| `NEXT_TARGET.md` | 是否存在获准的下一业务目标；当前为空 |

根 [`README.md`](../README.md) 是产品入口；根 [`ARCHITECTURE.md`](../ARCHITECTURE.md) 是兼容入口。
`AGENTS.md` 是操作政策；若其中旧的实现细节与当前 manifest/source 冲突，以 manifest/source 以及本索引
列出的 2026-08-28 cutover 文档为准。

## 当前产品/实现分界

- Egakium owns：Apps、产品 UI、Egakium identity/config/storage glue、`Product/EgakiumCanvas`、CEF bridge、
  CLI surface、产品测试与发行脚本。
- Intatis owns：共享 Core/Protocol/Providers/Conversation/Artifacts/Multimodal/SharedUI/Tools/Knowledge/
  Skills/Permission/MCP/AgentKernel/Cowork 和 `IntatisCodexRuntime`。
- macOS Code/Cowork production loop：`CodexAppServerSession`；项目工具只走 official dynamic tools。
- macOS UI：一个 Cowork presentation，左 CEF Canvas、右既有 harness；Chat/Code 仅隐藏。
- iOS：七个 Chat subset products，无 local agent/Codex Runtime/CEF。
- 发行：Intatis source 是 local build dependency；正式 App 自包含 exact Codex Runtime，不在用户机器上
  依赖 sibling checkout。

## 历史设计与验证

以下文件只作为当时的设计/调查证据，不能覆盖当前 manifest、source 或上方当前规范：

- `COWORK_AGENT_ARCHITECTURE.md`
- `COWORK_AGENT_INVOCATION_MODEL.md`
- `COWORK_CURRENT_FINDINGS.md`
- `COWORK_MIGRATION_PLAN.md`
- `COWORK_TASK_CONTEXT_MODEL.md`
- `COWORK_V0_10_SMOKE.md`
- `COWORK_V0_10_STATUS.md`
- `UI_COLOR_SYSTEM.md`
- `codex-report/`、`claude-report/`、`gemini-report/` 下的 dated reports
- `egakium-cef-baseline/` 下的迁移前 CEF 历史快照

历史文件中的版本、测试数量、截图、local package path 和环境结论只说明当时发生过什么。

## 维护纪律

- 外部 capability 先遵守 `/Users/vita/Vitemis/docs/DEPENDENCY_POLICY.md`，再按
  `OPEN_SOURCE_REUSE.md` 做项目准入。
- 不把共享 Intatis source、third-party vendor 或 standards 再复制回 Egakium。
- 升级前记录 Intatis exact HEAD/status/diff/untracked inventory；下游只读。
- 任何 `IntatisCodexRuntime` v1 major 或 external executable version/derivation 变化都要独立审查并重跑
  完整 contract/build/bundle/release gates。
- `NEXT_TARGET.md` 不保存已完成事项；没有明确授权时保持“无活跃目标”。
- 产品版本变化后运行 `scripts/check-version-consistency.sh`。
- 本地缓存、OpenSource gitlinks、Chromium/CEF assets 与 build artifacts 不因 runtime snapshot cutover
  自动获得清理授权。
