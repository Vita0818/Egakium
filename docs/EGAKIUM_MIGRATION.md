# EGAKIUM_MIGRATION

文档状态：当前迁移边界
迁移日期：2026-08-14
最近更新：2026-08-16
当前 Git root：`/Users/vita/Vitemis/Volans/Egakium`
业务基线来源：`/Users/vita/Vitemis/Intatis`

## 迁移结果

Ekagium 的仓库主体已经替换为 Intatis 的当前工作树，后续业务开发可以直接以该 SwiftPM +
XcodeGen 项目为基础。当前导入的是源目录在迁移时的实际 working-tree 状态，包括其当时存在的
未提交业务改动；它不是从某个干净 Git commit 重新检出的发布归档。

迁移保留了目标仓库自己的 `.git/`，所以当前仓库历史不属于源 Intatis。源 Intatis 的 Git metadata
没有导入，不能用当前仓库的 `HEAD` 推断导入业务树的源 commit 或源工作区差异。macOS/iOS 的
用户可见 GUI 品牌曾在 2026-08-15 使用 `Egakium`，并于 2026-08-16 按用户决定统一更正为
`Ekagium`；同日 marketing version 设为 `0.2`、build number 从 48 单调推进到 49。产品代码、target、
bundle identifier、模块、配置/数据路径与协议标识仍使用 `Intatis` identity。本次品牌与版本变更没有
执行内部符号批量重命名、bundle identity 迁移、协议迁移或数据目录迁移。

仓库物理目录 `/Users/vita/Vitemis/Volans/Egakium`、活跃文档文件名 `EGAKIUM_*.md`、只读历史目录
`docs/egakium-cef-baseline/` 与 Session Canvas `.egakium/` 路径作为迁移/兼容 identity 保持不变；
不得仅为拼写统一而移动这些路径或让既有 Session 失效。

## 迁移后的产品方向确认

2026-08-15 用户确认 Ekagium 后续不以导入的三栏 conversation harness 作为最终产品形态，而是以
现有 Cowork runtime 为业务底座建立 Canvas-first macOS 工作台：

- 中央主要区域是每个 Cowork Session 独立初始化的 HTML/DOM 空白画布；
- 右侧直接复用现有 Cowork harness，只做必要的父级布局和窄栏 UI 适配，不改其消息、任务、
  Agent、权限、EventLog、恢复或生命周期语义；
- 宿主从固定模板首次创建 Session `index.html`；用户最终选择方案一，允许 exact `@main` 通过既有
  workspace 工具和权限链直接编辑整份 HTML/CSS/JavaScript；
- ordinary sub-agent 需要并行时编辑互不重叠的辅助/元素 HTML，不让多个 Agent 并发修改同一主 HTML；
- exact `@main` 通过提示词负责主入口编辑、全局空间布局、协调和委派；
- ordinary sub-agent 默认在一次任务中编辑一个指定元素网页；该关系只是动态 prompt /
  TaskContract 约定，不是永久角色、Element owner、硬编码 hierarchy 或新 lease；
- 现有 Orchestrator、scheduler、AgentLoop、MessageBus/Mediator、PermissionEngine、七事件 fresh
  bootstrap、EventLog 与 AppSessionRuntimeManager 继续作为权威运行底座。

完整产品与架构合同见 `docs/EGAKIUM_CANVAS_COWORK.md`。同日后续已经实现最小方案一原型：
Session Canvas 初始化、exact `@main` 直编路径提示和独立 WKWebView Canvas 调试窗口已进入业务源码。
正式 CEF 接线、稳定元素/layout/event schema、Canvas bridge 与最终合窗仍是目标，不是当前完成度。

## 导入范围

从源 Intatis 工作树复制了业务源码、测试、SwiftPM/XcodeGen 配置、脚本、文档、NOTICE、
ThirdPartyNotices、Vendor、OpenSource、生成/缓存目录和普通资源。源项目根 `.agents/` 在单独的
窄范围授权后按原路径导入；嵌套上游目录中的普通 `.agents/` 资料也作为源文件复制。

为保持当前 Git root、避免携带凭据或浏览器会话，本次没有复制：

- 任意层级的 `.git` metadata；
- `.env` / `.env.*`、私钥、证书、provisioning profile 和常见本地凭据配置；
- 浏览器 Cookies、Login Data、Web Data、Network Persistent State、Sessions、Session Storage、
  Local Storage 等会话状态。

因此，本迁移是可开发的安全基线复制，不声称与源目录逐字节完全相同，也不应被当作凭据、登录态或
签名材料的备份。任何需要本地 secret 的构建或 smoke 都必须由用户在当前仓库中重新配置，且不得把
secret 提交到 Git。

## Ekagium 保留项

| 路径 | 保留内容 | 当前用途与边界 |
|---|---|---|
| `.git/` | Ekagium 原 Git 仓库 | 保持当前仓库身份；未导入 Intatis Git history |
| `docs/egakium-cef-baseline/` | 迁移前根 `AGENTS.md`、`CLAUDE.md`、`GEMINI.md`、`README.md` 与完整 `docs/` | 历史只读参考；活跃规则以根文件和当前 `docs/` 为准 |
| `Chromium/` | 迁移前下载/构建的 Chromium 本地树 | 不属于当前 Intatis 构建依赖；未经明确任务不得修改或删除 |
| `.deps/` | 迁移前官方 CEF 下载包与解包目录 | 保留 CEF 资产；当前 Intatis Swift 基线不自动消费它 |
| `build/` | 迁移前 Ekagium CMake/CEF 生成物 | 与 Intatis 的 `.build/` 不同；未经明确任务不得清理或覆盖 |

## 活跃文档解释

- 根 `AGENTS.md` 是迁移后规则入口，预期路径仍是实际 Git root
  `/Users/vita/Vitemis/Volans/Egakium`。
- `docs/CURRENT_STATE.md`、`docs/PROJECT_MAP.md`、`docs/ARCHITECTURE.md`、
  `docs/DO_NOT_BREAK.md`、`docs/TESTING.md` 等当前规范现以 Ekagium `v0.2 (49)` 为产品基线；其中
  标明 `v0.48 (48)` 或更早版本的历史测试、安装、签名和真实 provider 结果只证明当时状态，不能
  充当当前 `v0.2 (49)` 的验证证据。
- `docs/NEXT_TARGET.md` 已在 2026-08-15 替换为用户确认的 Ekagium Canvas/Cowork 活跃目标；旧
  Intatis v0.48 公证发布记录不再是本仓库的自动执行目标。
- `docs/EGAKIUM_CANVAS_COWORK.md` 是迁移后新确认的产品合同，明确 Canvas、独立 HTML 元素、
  `@main`/sub-agent prompt 分工和现有 Cowork harness 复用边界。
- 迁移前 Ekagium CEF 白画布原型的事实、架构、禁区和测试说明只在
  `docs/egakium-cef-baseline/` 中保留，不再描述当前业务主体。

## 已知差异与能力边界

源项目的 `.agents/skills/intatis-skill-creator/` 已经复制到当前根目录，但当前 Agent 会话的 Skill
注册表不会因为文件刚被复制就自动刷新。后续维护任务只能在会话实际暴露该 Skill 时调用它；目录存在
本身不构成运行时能力证明。源 Git metadata、凭据、签名材料和浏览器会话仍按上述安全边界有意省略。

## 本次验证边界

迁移当时只做了结构验证：核对源到目标的非敏感文件同步、历史文档快照、保留目录、敏感文件排除、
Git 状态和 Markdown whitespace；没有运行 Swift build、Swift test、Xcode build、CEF build、App
启动、真实 provider、签名、公证或发行验证。后续方案一原型已经单独运行定向 Swift tests 和
`IntatisMac` arm64 Debug build，精确证据见 `docs/TESTING.md`；仍未运行 CEF build、真实 GUI/provider、
签名、公证或发行验证。
