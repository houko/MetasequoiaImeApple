# 水杉输入法 Apple 平台版

本仓库包含水杉输入法（Metasequoia IME）的 Apple 平台原生前端。已发布的 macOS 前端基于 InputMethodKit 与 AppKit，iOS 宿主 App 与自定义键盘扩展正在逐步添加。两个平台共用同一套 C++ 组词引擎，各自的生命周期、输入路由、候选展示、设置界面与辅助功能 UI 则保持原生且相互独立。

目标模块边界与迁移顺序记录在 [Apple 平台架构文档](docs/apple-platform-architecture.md)。已发布的 macOS 实现位于 `platforms/macos/`，iOS 代码随开发进度放在 `platforms/ios/`。

## 平台状态

| 平台 | 状态 | 原生前端 |
|---|---|---|
| macOS 12+ | 已发布 | InputMethodKit 与 AppKit |
| iOS | 开发中 | 宿主 App 与 `UIInputViewController` 键盘扩展 |

iOS 版本不会移植 Windows 的 TSF 或 WebView2 宿主，而是复用 `MetasequoiaImeEngine`，并提供 iOS 专用的 UI 与文本文档适配层。

当前版本支持全拼输入、来自官方水杉词库的实时候选、拼音候选旁的辅助码提示、通过原生候选窗口或数字键 1–9 选择候选、空格上屏首选、回车上屏原始输入、退格、Esc、焦点切换时自动上屏、Shift+Space 在中文与直接英文输入之间切换，以及可选的全角模式（Option+Shift+H 切换）。原生的可拖动悬浮状态栏会持续显示中英文、标点和全角状态，并提供一键打开设置的入口；可在「外观」页中隐藏。启用全角模式后，未处于组词状态的 ASCII 字母、数字、标点和空格会转换为对应的 Unicode 全角形式，不影响拼音组词。

## 环境要求

- macOS 12 或更高版本
- Xcode 命令行工具
- CMake 3.25 或更高版本
- Homebrew 包：`boost`、`fmt` 和 `spdlog`
- Python 3

## 构建

```sh
git clone --recursive https://github.com/metasequoiaime/MSIME-Apple.git
cd MSIME-Apple
brew install cmake boost fmt spdlog
./platforms/macos/scripts/build.sh
```

词库构建会从官方源数据生成 `vendor/MetasequoiaImeDict/out/msime.db`。该数据库文件有意不纳入版本库。

## 为当前用户安装

```sh
./platforms/macos/scripts/install.sh
```

安装脚本会把已签名的 bundle 复制到 `~/Library/Input Methods`，完成注册，并自动为当前用户启用水杉输入法；整个过程不需要管理员权限。如果 macOS 拦截了 ad-hoc 构建，请在「隐私与安全性」中放行，再到「系统设置 > 键盘 > 文本输入 > 编辑」中启用。

## 设置

在「系统设置 > 键盘 > 文本输入 > 编辑」中选择水杉输入法，再选择其设置项，即可打开原生的「水杉输入法设置」面板。面板中可以选择全拼、小鹤双拼或 86 五笔，配置唯一四码五笔候选自动上屏，预览并切换原生候选窗口的横排与竖排形式，设置每页显示 5、7 或 9 个候选，选择小、标准或大号候选字体，指定 `- / =`、`[ / ]` 或 Page Up / Page Down 作为翻页键，启用全拼纠错与辅助码，切换中文标点转换，启用 Option+Shift+H 全角输入，以及控制选中候选是否更新词频学习。启用辅助码后，拼音候选会在括号中显示对应提示，与产品截图中的候选展示一致。这些选项按当前用户保存，在没有活动组词时于下一次按键前生效；正在进行的组词会沿用原有设置，直到上屏或取消。后续会继续增加更多输入与候选选项。

发布 ZIP 中还附带 `Open Settings.command` 作为直接入口。安装后打开它即可启动同一个原生面板，无需先切换到水杉；关闭面板只会退出这个独立的设置进程，输入法本身不受影响。

输入法使用 Sparkle 2 自动检查仓库的已签名更新源。可以直接在输入法菜单或设置面板中选择「检查更新…」手动检查。可用版本会在后台下载，解压前用项目的 Ed25519 更新密钥校验，并就地替换现有输入法 bundle 完成安装，用户无需自行解压或运行 ZIP 安装器。`-update.zip` 是 Sparkle 的更新载荷，不是供手动打开的安装包。appcast 本身同样经过签名，Sparkle 框架与发布工具在构建和发布配置中固定到已验证的版本。当发布签名凭据不可用时，兜底的未签名发布会有意省略 `appcast.xml`；下一个已签名版本发布后，Sparkle 自动更新即恢复。

文本输入菜单还会显示水杉当前处于「中文输入」还是「英文输入」模式。可以直接选择对应菜单项，也可以按 Shift+Space；切换到英文时会先把正在进行的中文组词上屏，之后的按键原样透传。Shift+Space 快捷键默认启用，与其他工作流冲突时可在设置中关闭。

## 开发测试

```sh
python3 platforms/macos/tests/create_fixture_dictionary.py /tmp/metasequoia-ime-test/msime.db
cmake -S . -B build-test -DCMAKE_BUILD_TYPE=Debug -DCMAKE_PREFIX_PATH="$(brew --prefix)" -DMETASEQUOIA_IME_DICTIONARY=/tmp/metasequoia-ime-test/msime.db
cmake --build build-test --parallel
ctest --test-dir build-test --output-on-failure --timeout 20
```

测试套件使用真实的 SQLite 表和生产环境的引擎路径，不会用伪造候选替代。

## 发布

合并到 `main` 会根据 conventional commit 历史更新 Release Please 的 pull request。合并该发布 PR 会更新 `version.txt`、`CMakeLists.txt` 和 `CHANGELOG.md`，创建对应的 `vX.Y.Z` 标签，构建并测试通用架构的输入法 bundle，然后发布带有以下产物的 GitHub Release：

- `MetasequoiaIME-vX.Y.Z-macos-universal.pkg`
- `MetasequoiaIME-vX.Y.Z-macos-universal.pkg.sha256`
- `MetasequoiaIME-vX.Y.Z-macos-universal.zip`
- `MetasequoiaIME-vX.Y.Z-macos-universal.zip.sha256`
- `MetasequoiaIME-vX.Y.Z-macos-universal-update.zip`
- `MetasequoiaIME-vX.Y.Z-macos-universal-update.zip.sha256`
- `appcast.xml`

当未配置 Apple 发布凭据时，工作流会发布同样的四份产物，但在扩展名前加上 `-unsigned`，并在 GitHub Release 中附加警告。未签名产物仅用于测试，可能需要在 macOS 隐私与安全性设置中显式放行。

常规安装请使用 ZIP 并运行其中的 `Install.command`，或使用 PKG 通过 macOS 原生安装器安装。两种方式都会安装当前用户的 bundle，并尝试自动注册并启用水杉，无需注销或重启 Mac。如果没有已登录的图形界面用户，或 macOS 拦截了未签名 App，可稍后在「系统设置 > 键盘 > 文本输入 > 编辑」中启用。

如果选择 PKG，请下载安装包及其校验和文件，校验通过后双击安装。它会把副本安装到当前用户的 `~/Library/Input Methods`；原生安装器可能会请求管理员授权。安装过程不会自动注销或重启 Mac。macOS 仍可能要求你在方便的时候注销并重新登录，新复制的输入法才会出现。

```sh
shasum -a 256 -c MetasequoiaIME-vX.Y.Z-macos-universal.pkg.sha256
```

当以下仓库 secret 全部配置完成时，发布构建会使用 Developer ID Application 身份签名、使用 Developer ID Installer 身份签名安装包，并在发布前完成公证。一个都未配置时，工作流会发布明确标注为未签名的产物。只配置了一部分时，工作流会在下载构建依赖前失败，以免产出标注含糊的产物。

- `MACOS_DEVELOPER_ID_CERTIFICATE_BASE64`
- `MACOS_DEVELOPER_ID_CERTIFICATE_PASSWORD`
- `MACOS_SIGNING_KEYCHAIN_PASSWORD`
- `MACOS_NOTARY_APPLE_ID`
- `MACOS_NOTARY_TEAM_ID`
- `MACOS_NOTARY_APP_SPECIFIC_PASSWORD`
- `MACOS_DEVELOPER_ID_APPLICATION`
- `MACOS_DEVELOPER_ID_INSTALLER`

本地开发构建仍为 ad-hoc 签名。安装后脚本会自动注册并启用水杉输入法；如果 macOS 拦截了该 bundle，请在「隐私与安全性」中放行，再到「系统设置 > 键盘 > 文本输入 > 编辑」中启用。

ZIP 通过 `Install.command` 提供同样的当前用户安装位置，是希望立即用上水杉、又不想注销或使用管理员权限时的推荐方式。安装器在替换已有安装前始终校验 bundle 的代码签名，随后向 macOS 注册并启用该 bundle，使其无需注销即可出现在输入法菜单中。如果注册或启用失败，已校验的 App 仍会保留在安装位置，安装器会引导你到「系统设置」中手动启用。已签名的发布还必须通过 Gatekeeper；明确标注为未签名的构建则需要输入 `I UNDERSTAND`，并可能需要在「系统设置 > 隐私与安全性」中显式放行。

校验 ZIP 的校验和，解压后运行 `Install.command`：

```sh
shasum -a 256 -c MetasequoiaIME-vX.Y.Z-macos-universal.zip.sha256
./MetasequoiaIME-vX.Y.Z/Install.command
```

## 卸载

发布 ZIP 中同样附带 `Uninstall.command`。它只移除当前用户的输入法，并移入废纸篓以便恢复。默认保留偏好设置与学习数据：

```sh
./MetasequoiaIME-vX.Y.Z/Uninstall.command
```

如果要把应用、偏好设置和学习数据一并移到废纸篓中的同一个恢复文件夹，请使用显式的数据移除选项：

```sh
./MetasequoiaIME-vX.Y.Z/Uninstall.command --remove-user-data
```

两种模式在修改文件前都要求输入 `REMOVE METASEQUOIAIME`。完成后请注销，让 macOS 刷新输入源缓存。

通过 PKG 安装时，同一个卸载脚本会保留在已安装的应用 bundle 内，因此即使没有发布 ZIP 也可以使用：

```sh
"$HOME/Library/Input Methods/MetasequoiaIME.app/Contents/Resources/Uninstall.command"
```

## 许可证

水杉输入法 Apple 平台版依据 GNU General Public License version 3 分发。发布归档、安装包和应用 bundle 均包含适用的 GPL 与第三方许可声明，详见 `LICENSE` 与 `THIRD_PARTY_NOTICES.txt`。

## 隐私与安全

输入处理与候选学习全部在设备本地完成，数据处理细节见 [PRIVACY.md](PRIVACY.md)。发现疑似安全漏洞请按 [SECURITY.md](SECURITY.md) 的说明私下报告，不要提交公开 issue。
