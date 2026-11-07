# 在场 · StillHere

**人可以离席，工作继续在场。**

[English](README.md) · [下载 Beta](https://github.com/0xZoharHuang/stillhere-mac/releases/tag/v0.4.0) · [交流与建议](https://github.com/0xZoharHuang/stillhere-mac/discussions)

StillHere 是独立运行的隐私壁纸工具，包含 macOS 和 Windows 原生实现。开启后，物理显示器显示自选图片，桌面会话继续运行；保护层不接收鼠标事件，也不取得键盘焦点。再次按快捷键即可退出防窥。

它不依赖 UU 或其他远程连接。你可以离开电脑，让自动化继续工作，偶尔再通过远程工具连接并操作桌面。

![默认梗图：我司雇我在](Sources/StillHere/Resources/ExistentialCapybara.png)

## 下载

- [下载 Mac 或 Windows 开箱包](https://github.com/0xZoharHuang/stillhere-mac/releases/tag/v0.4.0)：均附中英文快速开始说明；Windows 压缩包包含全部壁纸，解压后即可在设置中选择。Mac 为 Apple Silicon + Intel 通用构建，实际运行验收为 macOS 15.5 / Apple Silicon。Windows 要求见 [windows/README.md](windows/README.md)。

## macOS 使用

1. 打开 `StillHere.app`。应用常驻菜单栏，名称为“在场”。
2. 从菜单选择“开启隐私壁纸”，或按 **Control + Option + Command + P**。
3. 首次开启会先显示几秒钟的角落测试色块，验证普通截图和 ScreenCaptureKit 都能排除保护层。诊断可能需要你授权录屏；也可以在已有录屏权限的终端运行 `/Applications/StillHere.app/Contents/MacOS/StillHere --diagnose`，应用本身就无需新增录屏权限。检查不通过时不会开启全屏壁纸。
4. 回来后再按一次相同快捷键，立即返回桌面。壁纸上不显示快捷键提示。

打开菜单栏的“壁纸与设置”，进入「概览 / 壁纸库 / 偏好设置」界面。概览可直接开启防窥；macOS 壁纸库内有 24 张原创壁纸，也可选择自己的图片；偏好设置可选择是否在防窥期间保持电脑与显示器唤醒。系统主动锁屏、合盖或关机仍由 macOS 处理。

当前版本只通过菜单、快捷键或命令行请求切换，没有自动离席切换。

移动鼠标、普通按键和自动化输入不会自动解除保护。退出应用也会移除壁纸。

## 自动化兼容性

本工具使用 `NSWindow.sharingType = .none`，并把壁纸窗口设为鼠标穿透、不能成为键盘焦点的窗口。采集排除是一项**必须按系统版本和采集方式验证的行为**。Apple 的最新文档已将旧式窗口共享标记列为 legacy；因此本工具不会把该属性当成跨版本保证。

首次开启与系统 build 变化后，都需要重新通过采集检查。检查同时包含普通遮挡窗口的阳性对照，避免把“测试窗口没显示出来”误判成排除成功。

已在 macOS 15.5 / build 24F74 上确认：

| 路径 | 结果 |
| --- | --- |
| 普通 `CGWindowListCreateImage` 截图 | 保护层排除，下面画面可见 |
| ScreenCaptureKit，未设置排除列表 | 保护层排除，下面画面可见 |
| ScreenCaptureKit，显式排除窗口的对照 | 下面画面可见 |
| 测试保护层出现前后的前台应用 | 保持一致 |
| 原生电脑操作工具截图、点击、输入、再次截图 | 通过；能读到更新后的测试内容 |
| 旧版快捷键、密码及保护层 | 通过；新版本快捷键切换结果见各版本验收记录 |

完整应用的界面、输入和多显示器验收记录见 [verification/README.md](verification/README.md)。上面的结果不代表已经逐一验证每一种自动化、远程软件、显卡和未来系统版本。请在你实际使用的工具中确认截图、点击、输入和再次截图都正常后，再长期离席使用。

用户已在 Mac 显示器前确认当前版壁纸显示正常、不带快捷键提示且可直接返回桌面；尚未逐块屏幕单独记录观察结果，也没有进行独立的 UU 实时远控会话验收。远程采集会排除壁纸，因此远程桌面截图本身不能代替实体屏幕观察。

防窥不再使用密码；壁纸本身不会显示快捷键提示。

## 安装与构建

构建要求：macOS、Xcode Command Line Tools、Swift 5.9 或更新版本。部署目标为 macOS 14.0；当前实际运行验证环境为 macOS 15.5。

```bash
swift test
bash scripts/build-app.sh --universal
bash scripts/package.sh
bash scripts/package-ready-mac.sh
# Windows 上先运行 windows\build.cmd，再运行：
python scripts/package-windows.py dist/windows/StillHere.exe dist/StillHere-0.2.0-windows-ready.zip
```

产物：

- `dist/StillHere.app`：Apple Silicon + Intel 通用应用。
- `dist/StillHere-0.4.0-mac.zip`：应用压缩包。
- `dist/StillHere-0.4.0-mac.dmg`：拖入 Applications 的安装映像。
- `dist/SHA256SUMS.txt`：安装包校验值。

当前构建使用本地 ad-hoc 签名，尚未经过 Apple 公证。源代码构建不需要 Apple 开发者账号。

## 诊断与命令行

```bash
bash scripts/diagnose.sh
dist/StillHere.app/Contents/MacOS/StillHere --status
dist/StillHere.app/Contents/MacOS/StillHere --shield
dist/StillHere.app/Contents/MacOS/StillHere --unlock
```

`--unlock` 直接移除隐私壁纸；`--quit` 退出应用并移除壁纸。

开发时可以用 `STILLHERE_DATA_DIR` 指向隔离目录，避免修改日常配置。`--fixture` 会打开独立的自动化验证窗口，`--close-fixture` 关闭它；这些窗口不会出现在正常使用流程中。

## 本地数据与保护边界

数据保存在 `~/Library/Application Support/StillHere/`。应用不上传图片或截图，也不连接服务器。旧版本保存的密码校验文件不会被删除，但此版本不会读取或使用它。

StillHere 提供离席画面遮挡。知道快捷键的人可以直接退出防窥，桌面也保持可操作；它不能替代系统锁屏对物理访问的隔离。

## 壁纸

原创职场与 AI 梗壁纸均带中英文文案，灵感和生成记录见 [assets/wallpaper-gallery.md](assets/wallpaper-gallery.md)。Mac 版本内置图库；Windows 开箱包的 `Wallpapers` 文件夹包含同一组图片，可在应用中通过「选择壁纸」选择。也可选择自己的图片；静态 PNG 为当前默认交付格式。

[浏览全部 24 张壁纸](docs/WALLPAPERS.md)

## 原理参考

- [Apple：ScreenCaptureKit 的采集过滤与遮挡窗口](https://developer.apple.com/videos/play/wwdc2022/10155/)
- [Apple：窗口鼠标穿透](https://developer.apple.com/documentation/appkit/nswindow/ignoresmouseevents)
- [Apple：窗口共享属性的当前状态](https://developer.apple.com/documentation/appkit/nswindow/sharingtype-swift.enum)
- [Electron：当前 macOS 的采集排除兼容性说明](https://www.electronjs.org/docs/latest/api/browser-window#winsetcontentprotectionenable-macos-windows)

MIT License.
