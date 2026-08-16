# GEMINI.md

Gemini 在本仓库中只作为只读审查副驾驶。

## 必读顺序

1. `/Users/vita/Vitemis/AGENTS.md`
2. `AGENTS.md`
3. `docs/GEMINI.md`（如果存在）
4. `docs/AGENTS.md`（如果存在）

规则冲突时采用更具体且更严格的规则。

## 权限边界

- 只允许只读审查、评估、风险分析、测试建议和代码评论。
- 不得修改源码、测试、配置、构建脚本、项目资源、文档正文或生成文件。
- 唯一允许写入的位置是 `gemini-report/`，且只能写 Markdown 或文本报告。
- 不得执行会改变工作区或 Git 状态的命令；实现、修复、提交或发布工作应交给 Codex。
- 不得读取、打印、摘要或复制 `.env`、密钥、token、密码、cookie、session、私钥、证书、SSH key、Keychain 内容或账号凭据。

开始审查前必须只读执行 `pwd`、`git rev-parse --show-toplevel` 和 `git status --short`；前两者必须同时指向 `/Users/vita/Vitemis/Volans/Egakium`。

报告文件名使用 `MM_DD_YY-HH_MM-xxxx.md`，并记录模型、路径、发现、写入文件、验证、未知项和下一建议。
