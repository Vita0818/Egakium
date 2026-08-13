# DO_NOT_BREAK

本文列出 Egakium 当前可确认的工程、启动链路和本地数据边界。

## 工程禁区

- 不执行破坏性 Git 操作，不删除或覆盖用户未提交文件。
- 未经用户明确要求，不 add、不 commit、不 push、不创建 PR。
- Git 操作仅限 `/Users/vita/Vitemis/Volans/Egakium`，不得影响父仓库或相邻项目。
- 未经用户明确要求，不修改 `Chromium/checkout/src/` 中的上游内核源码。
- 不修改或删除 Chrome 地址栏、标签栏、书签、同步、扩展或 `chrome/browser/ui` 来制作 Egakium；正式产品不得启动完整 `chrome` target。
- 不以 Chromium `content_shell` 或自建 Content embedder 取代已确认的官方 CEF 二进制路线，除非用户明确重新决策。
- 不自行构建或 fork CEF/Chromium；CEF 集成必须使用官方 macOS ARM64 二进制发行包并固定版本与 SHA-256。
- 未经用户确认，不引入前端框架、AI/agent 框架、IPC、数据库或第三方依赖。
- 不把 `.deps/`、`build/`、`Chromium/`、`out/` 或 `.runtime/` 纳入 Git。
- 不直接修改 `.deps/cef/` 中的官方 CEF 发行文件；产品改动必须发生在本仓库源码和配置中。
- 不直接修改 `build/xcode/Egakium.xcodeproj/project.pbxproj` 或其他 CMake 生成的 Xcode 文件；使用 `scripts/generate-xcode-project.sh` 从 CMake 配置刷新。
- 保持根目录 `Egakium.xcodeproj/` 为真实工程目录，不得改回符号链接；共享 `Egakium` scheme 必须引用 `container:Egakium.xcodeproj`，不能绕回被忽略的支撑工程。
- 根目录工程是 CMake 配置的可跟踪快照；新增或删除 native target/source、调整 Helper/Framework/bundle 规则后必须运行 `scripts/generate-xcode-project.sh` 刷新，不能只在 Xcode GUI 中维护一份分叉配置。
- 不把 CEF 二进制、Framework 或解包内容复制进受 Git 跟踪的源码目录。
- `config/cef.cmake` 是唯一版本锁；更改 CEF 版本、平台、URL 或校验值必须作为显式升级任务，并重新执行 bundle、进程、UI 与退出验证。
- 保持 `src/canvas/index.html` 为画布业务入口，并保持 `#egakium-canvas` 作为当前稳定根锚点；若需要更改，必须同步启动器、测试和架构文档。
- 保持正式 bundle 中的 `com.vitemis.egakium` 主身份和 `com.vitemis.egakium.helper*` Helper 身份；Helper 必须继续配置为不可见 UI element，不能产生独立 Dock 图标。
- 保持正式命令行主链路为 `scripts/build-cef-app.sh` → `build/cef/src/native/Release/Egakium.app`，并保持正式 Xcode 开发链路为根目录 `Egakium.xcodeproj` → `build/xcode/src/native/{Debug,Release}/Egakium.app`；不得把历史 `out/Egakium.app` 重新包装成正式产物。
- `scripts/build-macos-app.sh` 是历史实验脚本，不得继续承担正式功能、隐式清理或重新编译 Chromium。
- CEF 原型已完成，但仍不得自动删除 `Chromium/`、现有实验启动器或历史产物；清理这些下载成本高或具有历史价值的资产必须由用户决定。
- 不绕过未来建立的认证、授权、输入校验、加密或数据保护机制。

## 敏感信息禁区

- 不读取、打印、摘要、复制或提交 `.env`、API key、token、密码、cookie、session、私钥、证书、SSH key 或账号凭据。
- 示例配置只能使用明确的占位值，不得包含真实凭据。

## 数据格式与协议禁区

当前没有元素数据格式或跨进程通信协议。建立任何持久化 schema、agent 消息或原生桥接协议时，应在变更前定义身份、版本、权限、兼容和迁移策略，并更新本文。

CEF bridge 必须异步、白名单化并校验页面来源与参数；不得暴露任意本机文件、进程或命令执行接口。

## 路径禁区

- 仓库根目录固定为 `/Users/vita/Vitemis/Volans/Egakium`。
- 父级 `/Users/vita/Vitemis` 是另一个 Git 仓库；不得把 Egakium 的提交与父仓库改动混在一起。
- 本地 Chromium 路径、`out/Egakium.app` 和 `.runtime/chromium-profile/` 都属于历史实验链路，必须保持忽略且不得描述为正式 CEF 产物。
- 正式本机构建固定输出到 `build/cef/src/native/Release/Egakium.app`；`.deps/` 和 `build/` 都必须保持忽略。
- 正式 CEF app 必须自包含 Framework、资源和 Helper；不得引用 `Chromium/checkout/.../Chromium.app`。
- 当前 CEF 构建使用 `USE_SANDBOX=OFF`，只有本地 ad-hoc/linker 签名；不能描述为已经完成正式签名、公证、沙盒、自动更新或可对外分发的产品。

## 回归与验证要求

- 文档变更至少通过 `git diff --check`。
- 历史启动器变更至少运行 `zsh -n`、`plutil -lint`、`scripts/build-macos-app.sh` 和对应实验 bundle 检查。
- 正式原生壳、CMake 或 plist 变更至少运行 `zsh -n scripts/build-cef-app.sh`、`plutil -lint`、`scripts/build-cef-app.sh`、Mach-O 架构检查和 bundle 结构检查。
- Xcode 入口或 Xcode 专用 CMake 设置变更至少运行 `zsh -n scripts/generate-xcode-project.sh`、生成脚本、`xcodebuild -list -project Egakium.xcodeproj`，并从根目录工程构建受影响的 Debug/Release 配置。
- 画布变更至少重新运行 `scripts/build-cef-app.sh`，确认源 HTML 与 bundle 副本一致，并执行人工 CEF 渲染验证；自动化浏览器测试建立后再替代人工边界。
- CEF 升级必须验证固定版本/校验、ARM64 二进制、bundle 完整性、Dock 身份、窗口归属、Helper 进程、页面加载、输入/GPU 基线与正常退出。
- 无法运行验证时必须说明原因与未验证边界。
