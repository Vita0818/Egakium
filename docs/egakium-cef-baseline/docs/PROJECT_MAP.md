# PROJECT_MAP

最近自查日期：2026-08-13

当前仓库包含正式 CEF 原生壳、HTML 白画布，以及保留作历史基线的 `chrome --app` 实验壳。

## 目录结构总览

```text
Egakium/
├── .gitignore                    # 本地依赖、产物与敏感配置忽略规则
├── CMakeLists.txt                # 正式 CEF 工程入口
├── Egakium.xcodeproj/            # 根目录实体 Xcode 工程包（非符号链接）
│   ├── project.pbxproj           # 主 App、Helper 与 CEF wrapper targets
│   └── xcshareddata/xcschemes/
│       └── Egakium.xcscheme      # 共享 Build/Run scheme
├── AGENTS.md                     # Codex 项目入口与工作边界
├── CLAUDE.md                     # Claude 只读审查入口
├── GEMINI.md                     # Gemini 只读审查入口
├── README.md                     # 项目概览与使用入口
├── config/
│   └── cef.cmake                 # 官方 CEF 版本、URL、SHA-1/SHA-256 锁
├── .deps/                        # 忽略的 CEF 压缩包与解包内容
├── build/                        # 忽略的 CMake/Ninja/Xcode 生成内容与 app 产物
├── Chromium/                     # 忽略的历史 Chromium checkout 与构建产物
├── packaging/
│   └── macos/
│       ├── Egakium               # 历史实验 app bundle 启动器模板
│       └── Info.plist            # 历史实验 app bundle 元数据模板
├── scripts/
│   ├── fetch-cef.cmake           # 下载、校验、解包固定 CEF 发行包
│   ├── build-cef-app.sh          # 正式 CEF ARM64 Release 构建入口
│   ├── generate-xcode-project.sh # 生成/刷新根目录 Xcode 开发入口
│   └── build-macos-app.sh        # 组装历史实验 Egakium.app
├── src/
│   ├── canvas/
│   │   └── index.html            # 当前业务入口与白画布
│   └── native/
│       ├── CMakeLists.txt        # Egakium 与 Helper targets/bundle 组装
│       ├── egakium_app.h/.mm     # CEF BrowserProcessHandler 与窗口创建
│       ├── egakium_client.h/.cc  # Browser 生命周期和空右键菜单
│       └── mac/
│           ├── egakium_main.mm   # macOS/CEF 主进程入口
│           ├── egakium_helper.cc # CEF 子进程入口
│           ├── Info.plist.in     # 主 app bundle 元数据
│           └── helper-Info.plist.in # Helper 身份与后台属性
├── out/                          # 忽略的历史实验产物
├── .runtime/                     # 忽略的历史 Chromium profile
└── docs/
    ├── ARCHITECTURE.md    # 架构基线
    ├── CURRENT_STATE.md   # 当前真实状态
    ├── DO_NOT_BREAK.md    # 不可破坏约束
    ├── PROJECT_MAP.md     # 本文件
    ├── TECHNICAL_ROUTE.md # 已接受的 CEF 技术路线
    └── TESTING.md         # 验证基线
```

`.git/` 是本仓库的 Git 元数据目录，未在结构图中展开。`.deps/`、`build/`、`Chromium/`、`out/` 和 `.runtime/` 不属于应提交的项目源码。

## Target / 模块

- `canvas`：无框架 HTML/CSS 画布入口。
- `CEF native shell`：当前正式运行壳；使用 CEF Views 创建窗口化 BrowserView，加载 bundle 内白画布并管理关闭生命周期。
- `CEF helpers`：主 Helper 及 Alerts/GPU/Plugin/Renderer bundle；通过 `LSUIElement=1` 保持为后台子进程身份。
- `CEF binary dependency`：固定版本的官方 Standard Distribution，只存在于忽略的 `.deps/`。
- `experimental macos launcher`：生成后的历史实验 `Egakium.app` 启动完整 Chromium 并传入画布 URL；不再扩展。
- `historical Chromium runtime`：本地预编译基线，不是正式 Egakium runtime。

## 关键文件

- 产品入口：`src/canvas/index.html`。
- Xcode 开发入口：根目录实体工程包 `Egakium.xcodeproj/`；其中实际保存 `project.pbxproj`、workspace 设置和共享 scheme，不经过符号链接。
- Xcode 工程生成入口：`scripts/generate-xcode-project.sh`；先生成被忽略的 CMake 支撑工程，再把工程文件同步到根目录并生成唯一共享 scheme `Egakium`。
- 正式原生入口：`src/native/mac/egakium_main.mm`。
- 正式 CEF 初始化与窗口入口：`src/native/egakium_app.mm`。
- 正式构建入口：`scripts/build-cef-app.sh`。
- 固定依赖入口：`cmake -P scripts/fetch-cef.cmake`。
- 实验启动器模板：`packaging/macos/Egakium`。
- 实验 Bundle 配置：`packaging/macos/Info.plist`。
- 实验构建入口：`scripts/build-macos-app.sh`。
- 当前实验链路：`out/Egakium.app` → 完整 Chromium 可执行文件 → `--app=file://<canvas>`。
- 正式链路：Egakium 主程序 → CEF Views 顶层窗口/BrowserView → `Contents/Resources/canvas/index.html`。
- 路线决策：`docs/TECHNICAL_ROUTE.md`。
- 自动化测试：尚不存在。

## 生成物 / 产物

- 历史 Chromium 构建：`Chromium/checkout/src/out/EgakiumNative/Chromium.app`。
- 实验 Egakium 启动壳：`out/Egakium.app`。
- Chromium profile：`.runtime/chromium-profile/`。
- CEF 下载包：`.deps/downloads/cef_binary_151.3.17+gf059e67+chromium-151.0.7922.138_macosarm64.tar.bz2`。
- CEF 解包目录：`.deps/cef/cef_binary_151.3.17+gf059e67+chromium-151.0.7922.138_macosarm64/`。
- 正式 CEF 开发产物：`build/cef/src/native/Release/Egakium.app`。
- CMake Xcode 生成/构建支撑目录：`build/xcode/`；根目录实体工程从这里刷新，但 Build/Run 的共享 scheme 引用根目录工程自身。
- Xcode Debug/Release 产物：`build/xcode/src/native/{Debug,Release}/Egakium.app`。

## 脚本与工具

- `scripts/fetch-cef.cmake`：只接受 `config/cef.cmake` 固定的官方包和 SHA-256；已有合法依赖时不会重复下载。
- `scripts/build-cef-app.sh`：CMake + Ninja ARM64 Release 正式构建入口；使用 `USE_SANDBOX=OFF`，输出本机开发 app。
- `scripts/generate-xcode-project.sh`：使用 CMake Xcode generator 生成 Debug/Release 原生 targets 与 Helper 依赖，把工程元数据同步为根目录实体 `Egakium.xcodeproj/`，并确保共享 scheme 引用根目录工程自身。
- `scripts/build-macos-app.sh`：重现实验链路；不得视为正式 CEF 构建入口。

## 不确定项

前端框架、无限画布元素模型、agent 协议、原生桥接、内部 scheme、CEF sandbox、签名、公证与分发方式均待后续任务确定。
