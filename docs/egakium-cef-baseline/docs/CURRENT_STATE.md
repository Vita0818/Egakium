# CURRENT_STATE

最近一次自查日期：2026-08-13

## 当前真实状态总览

Egakium 已从技术路线验证阶段进入可运行的 CEF 白画布原型阶段。当前目标平台为 macOS Apple Silicon，以 HTML/DOM 作为未来画布和元素载体。

已完成的 `Egakium.app → Chromium --app=file://... → 白画布` 是实验链路。它验证了页面加载，但实际 Dock 身份、窗口体系和运行应用仍属于完整 Chromium，因此已明确判定为不符合正式产品方向。

正式技术路线已经落地：使用官方 CEF macOS ARM64 二进制发行包，由 Egakium 自己拥有 app、Dock 身份、原生窗口、菜单和生命周期，CEF 只作为窗口内嵌渲染运行时。当前应用启动后只显示 bundle 内的纯白 HTML 画布。

## 已有能力

- Git 仓库：独立 Git root 已建立，默认分支为 `main`，`origin` 指向 `https://github.com/Vita0818/Egakium`。
- Agent 入口：已建立 Codex、Claude 和 Gemini 的项目级规则入口。
- 项目文档：已建立状态、结构、架构、禁区和测试文档基线。
- 敏感文件保护：`.gitignore` 已忽略 `.env`、`.env.*` 和 `.DS_Store`，并允许未来提供不含秘密的 `.env.example`。
- 历史 Chromium 基线：本地 `Chromium/checkout/src/out/EgakiumNative/Chromium.app` 已成功构建，版本输出为 `Chromium 153.0.8002.0`；它不再是正式运行时方案。
- 白画布：`src/canvas/index.html` 提供全窗口、无边距、纯白的 HTML 根画布 `#egakium-canvas`。
- CEF 版本锁：`config/cef.cmake` 固定 CEF `151.3.17+gf059e67+chromium-151.0.7922.138`、`macosarm64`、官方 CDN URL、SHA-1 和 SHA-256。
- 官方依赖：Standard Distribution 已下载到 `.deps/downloads/` 并解包到 `.deps/cef/`；两者都被 Git 忽略。官方 SHA-1 和固定 SHA-256 均已验证。
- 正式原生壳：`src/native/` 实现 CEF 初始化、CEF Views 顶层窗口、BrowserView、生命周期、Helper 入口、缓存路径和空白画布加载。
- 正式构建：`scripts/build-cef-app.sh` 使用 CMake + Ninja 生成 ARM64 Release 应用，产物是 `build/cef/src/native/Release/Egakium.app`。
- Xcode 开发入口：根目录 `Egakium.xcodeproj/` 是实体工程包，实际包含 `project.pbxproj`、workspace 设置与共享 `Egakium` scheme，不是符号链接；`scripts/generate-xcode-project.sh` 负责准备依赖并从 CMake 配置刷新它。
- Xcode 构建：Debug 与 Release 均已通过 `xcodebuild` 验证，产物分别位于 `build/xcode/src/native/Debug/Egakium.app` 与 `build/xcode/src/native/Release/Egakium.app`。
- 自包含 bundle：正式产物包含 CEF Framework、官方资源、Egakium Helper 变体及 `Resources/canvas/index.html`，不引用本地 `Chromium.app`。
- 运行身份：Bundle Identifier 为 `com.vitemis.egakium`，仅 Egakium 显示为可见应用；Renderer/GPU/Network/Storage 等通过 Egakium Helper 后台运行。
- 本地数据：CEF 用户数据根目录显式设为 `~/Library/Application Support/Egakium/CEF`，不再使用通用的 `CEF/User Data` 名称。
- 实验壳：`scripts/build-macos-app.sh` 生成 `out/Egakium.app` 并调用完整 Chromium 的 `--app` 模式；该链路只保留作历史验证。
- 技术路线：`docs/TECHNICAL_ROUTE.md` 已记录官方 CEF ARM64 二进制、窗口内嵌渲染、内部资源、薄原生壳和 Helper 多进程边界。

## 未完成 / 进行中

- 无限画布的平移、缩放、选中、拖拽和元素模型尚未实现。
- AI、自然语言、语音、main agent、sub-agent 及其 IPC 尚未实现。
- 前端框架尚未选择；当前刻意保持原生 HTML/CSS。
- 当前画布通过 bundle 内 `file://` URL 加载；稳定的 `egakium://app/` 内部来源尚未实现。
- CEF sandbox 当前明确关闭；正式沙盒策略尚未实现和验证。
- Developer ID 签名、公证、权限声明、自动更新和发布流程尚未建立；当前只有可在本机运行的开发产物。
- 尚无自动化测试框架、lint、format、签名、公证或发布流程。

## 风险

- 历史实验 `out/Egakium.app` 仍依赖仓库内的 Chromium 可执行文件；它不是正式产物，也不能作为后续功能开发基础。
- CEF 官方二进制体积仍然较大；需要固定可信版本与校验值，并保证下载缓存、Framework 和生成物不会误入 Git。
- 当前正式 app 约 321 MiB，解包的 CEF 约 777 MiB，原始压缩包约 284 MiB；`.deps/` 与 `build/` 必须继续保持忽略。
- macOS CEF bundle 对 Framework、资源和 Helper app 结构有严格要求；后续签名、公证和沙盒必须覆盖所有嵌套代码。
- `file://` 足够支撑当前静态画布，但未来接入模块加载、网络权限、持久化和原生能力时需要重新评估来源与安全边界。
- 上游 Chromium checkout 与产物规模很大，必须保持为忽略的本地依赖，避免误纳入 Egakium Git 历史。
- 当前 CEF 已在 Xcode 27/macOS 27/AppleClang 21 上实际构建和启动成功；但这比发行包声明的 Xcode 16+ 基线更新，升级或发布时仍需重新验证。
- 当前 `USE_SANDBOX=OFF`，进程命令行会带 `--no-sandbox`；在加载不可信远程内容或暴露 native bridge 前必须先完成安全评估。
- 根目录 Xcode 工程本身可以直接打开，但其构建阶段仍依赖被忽略的 `build/xcode/` CMake 支撑文件与 `.deps/` CEF 依赖；新 checkout、移动仓库或删除 `build/` 后，首次构建前必须运行 `scripts/generate-xcode-project.sh` 刷新当前路径并准备支撑文件。

## 工作区状态

- `Chromium/`、`.deps/`、`build/`、`out/` 和 `.runtime/` 是忽略的本地目录。
- Egakium 源码、根目录 Xcode 入口、打包模板、构建脚本与文档变更尚未提交。
- 未执行 Git add、commit 或 push。

## 文档与源码冲突

当前 CEF 源码、构建配置和本文状态一致。旧 `chrome --app` 文件仍保留在独立历史路径中，这是有意保留的迁移基线，不再代表当前正式架构。
