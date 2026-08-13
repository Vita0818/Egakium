# TESTING

最近自查日期：2026-08-13

## 环境

- 目标平台：macOS Apple Silicon。
- 当前实验 runtime：本地 `EgakiumNative` Chromium 153.0.8002.0；不属于正式路线。
- 正式 runtime：官方 CEF `151.3.17+gf059e67+chromium-151.0.7922.138` macOS ARM64 Standard Distribution。
- 画布：原生 HTML/CSS，无包管理器或第三方依赖。
- 已验证工具链：macOS 27.0、Xcode 27.0、AppleClang 21、CMake 4.3.2、Ninja、arm64。
- 最低部署目标：macOS 12.0。
- 凭据：不需要；不得把真实凭据写入仓库或启动参数。

## 历史 Chromium 实验构建

重现 `chrome --app` 实验壳：

```sh
./scripts/build-macos-app.sh
```

该脚本不会编译 Chromium，但仍会启动完整 Chromium，因此不是正式 CEF 构建入口，只保留作历史复现。它要求以下本地可执行文件存在：

```text
Chromium/checkout/src/out/EgakiumNative/Chromium.app/Contents/MacOS/Chromium
```

## 正式 CEF 构建

首次下载、校验并解包固定的官方 CEF：

```sh
cmake -P scripts/fetch-cef.cmake
```

版本、URL、官方 SHA-1 和固定 SHA-256 位于 `config/cef.cmake`。生成 ARM64 Release app：

```sh
./scripts/build-cef-app.sh
```

等价的底层命令为：

```sh
cmake -S . -B build/cef -G Ninja \
  -DPROJECT_ARCH=arm64 \
  -DCMAKE_OSX_ARCHITECTURES=arm64 \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=12.0 \
  -DUSE_SANDBOX=OFF
cmake --build build/cef --target Egakium --parallel
```

正式开发产物：

```text
build/cef/src/native/Release/Egakium.app
```

当前 app 约 321 MiB。首次构建会编译 `libcef_dll_wrapper` 与少量 Egakium 源码，不会编译 Chromium；本机第一次构建约半分钟，未改原生代码的再次构建为亚秒级且显示 `ninja: no work to do`。

## Xcode 开发工程

生成或刷新根目录 Xcode 入口：

```sh
./scripts/generate-xcode-project.sh
open ./Egakium.xcodeproj
```

根目录 `Egakium.xcodeproj/` 是实体工程包，不是符号链接；其中实际包含 `project.pbxproj`、workspace 设置和共享 scheme。`build/xcode/` 继续承载被忽略的 CMake 支撑文件与编译产物。共享 scheme 只有 `Egakium`，Run 默认使用 Debug。命令行等价验证为：

```sh
xcodebuild -list -project Egakium.xcodeproj
xcodebuild -project Egakium.xcodeproj \
  -scheme Egakium \
  -configuration Debug \
  -derivedDataPath build/xcode/DerivedData \
  build
xcodebuild -project Egakium.xcodeproj \
  -scheme Egakium \
  -configuration Release \
  -derivedDataPath build/xcode/DerivedData \
  build
```

Xcode 产物分别位于 `build/xcode/src/native/Debug/Egakium.app` 与 `build/xcode/src/native/Release/Egakium.app`。两种配置都使用 CMake 定义的相同主 App、五种 Helper、CEF Framework 和画布复制规则。

## 测试

尚无单元测试或 UI 自动化框架。正式 CEF 原型的静态与打包检查：

```sh
zsh -n scripts/build-cef-app.sh
zsh -n scripts/generate-xcode-project.sh
plutil -lint src/native/mac/Info.plist.in src/native/mac/helper-Info.plist.in
cmake -P scripts/fetch-cef.cmake
./scripts/build-cef-app.sh
./scripts/generate-xcode-project.sh
test -d Egakium.xcodeproj
test ! -L Egakium.xcodeproj
test -f Egakium.xcodeproj/project.pbxproj
rg 'container:Egakium.xcodeproj' \
  Egakium.xcodeproj/xcshareddata/xcschemes/Egakium.xcscheme
xcodebuild -list -project Egakium.xcodeproj

APP=build/cef/src/native/Release/Egakium.app
test -x "$APP/Contents/MacOS/Egakium"
test -f "$APP/Contents/Resources/canvas/index.html"
cmp src/canvas/index.html "$APP/Contents/Resources/canvas/index.html"
file "$APP/Contents/MacOS/Egakium"
file "$APP/Contents/Frameworks/Chromium Embedded Framework.framework/Chromium Embedded Framework"
plutil -p "$APP/Contents/Info.plist"
otool -L "$APP/Contents/MacOS/Egakium"
git diff --check
git status --short
```

## Lint / Format

尚无 HTML、CSS 或 shell lint/format 依赖。引入前端框架时应同时确定 lint、format、类型检查和测试入口。

## 历史实验手动验证矩阵

1. 运行 `./scripts/build-macos-app.sh`。
2. 打开 `out/Egakium.app`。
3. 观察该方式实际仍由 Chromium 拥有运行应用和 Dock 身份；它只用于验证历史行为。
4. 确认内容区域为覆盖整个窗口的纯白画布，没有边距、滚动条或可见控件。
5. 修改 `src/canvas/index.html` 的背景色，刷新或重启窗口，确认修改生效且无需重编 Chromium；验证后恢复白色。

## 正式 CEF 原型验证矩阵

1. 验证主 app 和所有 Mach-O 二进制均为 Apple Silicon ARM64。
2. 验证 app 名称、Dock 身份和 Bundle Identifier 均属于 Egakium。
3. 验证 Egakium 自己拥有原生窗口，内容区域只显示白色 HTML 画布。
4. 验证不出现 Chromium 地址栏、标签栏、首次运行页或普通浏览器窗口。
5. 验证 CEF Framework、locale、pak、snapshot 等资源完整且 app 不引用本地 `Chromium.app`。
6. 验证 Renderer/GPU/Utility Helper 以 Egakium 身份运行且不显示独立 Dock 图标。
7. 验证鼠标、键盘、输入法、窗口缩放、GPU 合成和页面刷新基线。
8. 验证关闭最后窗口后，CEF 消息循环和所有 Helper 正常退出。
9. 验证修改 HTML/CSS/TypeScript 不触发 Chromium/CEF 重编译。
10. 验证没有修改 Chromium/CEF 底层源码，并在白画布闭环完成后停止。

## 2026-08-13 实际验证结果

- 官方索引版本：CEF `151.3.17` / Chromium `151.0.7922.138` / `macosarm64` / stable。
- 下载包大小：297,935,608 bytes；官方 SHA-1 与固定 SHA-256 均匹配。
- CMake 配置：`Darwin / arm64 / Release / sandbox OFF`，一次通过。
- 编译：228 个目标；首次因 Egakium 源文件缺少 `cef_app.h` 在最后一个对象处失败，补齐后增量构建成功；未修改任何 CEF 文件。
- 架构：主程序、Renderer Helper 和 CEF Framework 均由 `file` 确认为 Mach-O 64-bit arm64。
- bundle：包含 CEF Framework、五种 Helper bundle、CEF 资源和 `canvas/index.html`；页面副本与源文件逐字节一致。
- 身份：主 Bundle Identifier 为 `com.vitemis.egakium`；Helper IDs 为 `com.vitemis.egakium.helper*` 且 `LSUIElement=1`。
- 可视验证：应用窗口内容为纯白 HTML 画布，只保留 macOS 原生标题栏；未出现地址栏、标签栏、工具栏、首次运行页或普通 Chromium 窗口。
- 右键验证：白画布右键后 Accessibility tree 无变化，未弹出 Chromium 浏览器菜单。
- 进程验证：实际观察到 Egakium GPU、Network、Storage 与 Renderer Helper；Computer Use 的可见应用列表中只有主 Egakium，没有 Helper Dock 应用。
- 本地数据：Helper 命令行确认 `--user-data-dir=~/Library/Application Support/Egakium/CEF`。
- 退出验证：点击最后窗口的关闭按钮后，主进程与全部 Helper 均退出。
- 增量验证：再次运行 `scripts/build-cef-app.sh` 成功并报告 `ninja: no work to do`。
- Xcode 入口：根目录 `Egakium.xcodeproj/` 已确认为真实目录而非符号链接，实际包含工程文件、workspace 设置与共享 `Egakium` scheme；scheme 的四处 BuildableReference 均引用 `container:Egakium.xcodeproj`，`xcodebuild -list` 识别到完整 target 图和 Debug/Release 配置。
- Xcode 构建：从根目录 `Egakium.xcodeproj` 分别执行 Debug 与 Release 构建，均以 `BUILD SUCCEEDED` 完成；主 App、五种 Helper、CEF wrapper、Framework 和画布资源均进入对应产物。
- Xcode 设置：显式使用 macOS SDK、ARM64、正确的主/Helper Bundle Identifier，并保持当前原型 `CODE_SIGNING_ALLOWED=NO`；先前空 Bundle Identifier 警告在正式生成设置中已消除。

## 验证边界声明

当前没有单元测试、集成测试或持续 UI 自动化。白画布 UI、可见应用身份和关闭行为使用本机 Computer Use/进程检查验证；下载脚本的“已有合法包”分支已运行，首次网络下载本身由同一官方 URL 通过 `curl` 完成。

当前构建明确是本机开发原型：`USE_SANDBOX=OFF`；主 app 与嵌套代码仅有 linker 生成的 ad-hoc 签名，`codesign --verify --deep --strict` 不通过，`spctl` 也不认可为发布包。Developer ID 签名、公证、正式 sandbox、自动更新和分发验证均未运行，也不属于本阶段完成项。

未对麦克风、输入法、复杂键盘输入、远程网络内容、native bridge 或多窗口功能做产品级验证，因为这些能力尚未实现或不在当前纯白画布任务范围内。
