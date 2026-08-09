# Egakium 项目常驻上下文

本文件继承 `/Users/vita/Vitemis/AGENTS.md` 中的 Vitemis 通用 Agent 规则。若本文件与通用规则冲突，在不违反系统和用户指令的前提下，以更具体、更严格的规则为准。

## 必读顺序

执行任何源码、配置、构建脚本或测试修改前，依次阅读：

1. `/Users/vita/Vitemis/AGENTS.md`
2. `docs/CURRENT_STATE.md`
3. `docs/PROJECT_MAP.md`
4. `docs/ARCHITECTURE.md`
5. `docs/DO_NOT_BREAK.md`
6. `docs/TESTING.md`
7. `docs/NEXT_TARGET.md`（如果存在）

文档与源码、工程配置、测试或脚本冲突时，以当前源码和配置为准，并在最终报告中指出冲突。

## 工作目录检查

每轮开始在项目根目录执行：

```sh
pwd
git rev-parse --show-toplevel
git status --short
```

`pwd` 与 Git root 必须同时为：

```text
/Users/vita/Vitemis/Volans/Egakium
```

若不匹配，停止修改并报告路径问题。先区分用户已有改动与本轮改动，不得覆盖、回退或清理用户改动。

## 修改边界

本仓库目前是尚未确定技术栈的空白项目。

- 当前允许按用户任务修改根目录项目文档及 `docs/`。
- 业务源码目录、构建入口和测试入口均为 `UNKNOWN`；技术选型确定后必须及时补充本文件与相关文档。
- 创建源码结构、选择框架、引入依赖或配置发布流程前，必须有明确的用户任务或已确认的项目目标。
- 不得修改当前 Git root 之外的父仓库或相邻项目。

## 禁止事项

- 不执行破坏性 Git 操作，不删除用户未提交文件。
- 未经用户明文要求具体 Git 操作，不 add、不 commit、不 push、不创建 PR。
- 若用户要求提交，只提交当前 Git root 中与任务相关的文件，不处理父仓库、子仓库、submodule 或依赖 checkout。
- 不读取、打印或提交 `.env`、密钥、token、密码、cookie、session、私钥、证书或账号凭据。
- 在技术栈未确认前，不臆造入口文件、模块、构建命令、测试命令或架构结论。
- 不引入新依赖，不改构建脚本或测试源码，除非任务明确要求。

## 当前项目理解

- 项目阶段：基础初始化。
- 业务源码：尚不存在。
- target / module：尚不存在。
- 构建入口：`UNKNOWN`。
- 测试入口：`UNKNOWN`。
- 产品目标与核心链路：需要用户后续确认。

## 文档索引

- `docs/CURRENT_STATE.md`：当前真实状态、未完成项和风险。
- `docs/PROJECT_MAP.md`：目录、模块、入口和产物地图。
- `docs/ARCHITECTURE.md`：总体架构、数据流、安全边界及结论来源。
- `docs/DO_NOT_BREAK.md`：工程、数据、协议、路径与回归禁区。
- `docs/TESTING.md`：环境、构建、测试、静态检查和验证边界。
- `docs/NEXT_TARGET.md`：临时下一目标；仅在目标具体且有效时存在，完成或失效后删除。

## 完成标准

- 说明实际阅读或检查过的源码、配置、测试和文档。
- 只修改任务范围内文件，并保留用户已有改动。
- 运行与风险相称的检查；纯文档任务至少运行 `git diff --check` 与 `git status --short`。
- 已完成的持久性变化应及时回写相关项目文档；无需更新时在最终报告说明原因。
- 未运行构建或测试时，在最终报告中明确说明。

## 最终报告

建议包含：`MODEL_CHECK_RESULT`、`PATH_CHECK_RESULT`、`FILES_WRITTEN`、`PROJECT_AUDIT_SUMMARY`、`DOCS_CONTENT_SUMMARY`、`VALIDATION_RESULT`、`UNCERTAINTIES`、`NEXT_RECOMMENDED_ACTION`。
