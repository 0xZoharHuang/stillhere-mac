# 在场 · StillHere

**人可以离席，工作继续在场。**

StillHere 是独立运行的隐私壁纸工具，包含 macOS 和 Windows 原生实现。开启后，物理显示器显示自选图片，桌面会话继续运行；保护层不接收鼠标事件，也不取得键盘焦点。退出防窥需要应用密码。

它不依赖 UU 或其他远程连接。你可以离开电脑，让自动化继续工作，偶尔再通过远程工具连接并输入密码返回桌面。

![默认梗图：我司雇我在](Sources/StillHere/Resources/ExistentialCapybara.png)

## 下载

- [macOS 0.1.0：ZIP 与 DMG](https://github.com/0xZoharHuang/stillhere-mac/releases/tag/v0.1.0)，Apple Silicon + Intel 通用构建；实际运行验收为 macOS 15.5 / Apple Silicon。
- [Windows 测试候选](https://github.com/0xZoharHuang/stillhere-mac/releases/tag/windows-v0.1.0-rc.6)，完整键鼠与密码验收仍在进行。Windows 的要求、构建与使用见 [windows/README.md](windows/README.md)。

## macOS 使用

1. 打开 `StillHere.app`。应用常驻菜单栏，名称为“在场”。
2. 首次运行，设置一个至少 6 位的退出密码。应用不附带通用默认密码。
3. 从菜单选择“开启隐私壁纸”，或按 **Control + Option + Command + P**。
4. 首次开启会先显示几秒钟的角落测试色块，验证普通截图和 ScreenCaptureKit 都能排除保护层。诊断可能需要你授权录屏；也可以在已有录屏权限的终端运行 `/Applications/StillHere.app/Contents/MacOS/StillHere --diagnose`，应用本身就无需新增录屏权限。检查不通过时不会开启全屏壁纸。
5. 回来后按同一快捷键，输入退出密码。密码错误或取消对话框时，保护继续生效。

“壁纸与退出密码”可以替换图片、修改退出密码，以及选择是否在防窥期间保持电脑与显示器唤醒。系统主动锁屏、合盖或关机仍由 macOS 处理。

当前版本只通过菜单、快捷键或命令行请求切换，没有自动离席切换。

正在防窥时退出应用也需要密码。移动鼠标、普通按键和自动化输入不会自动解除保护。

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
| 快捷键开启与请求退出 | 通过 |
| 错误密码、取消退出 | 两块屏幕保持保护 |
| 正确密码退出应用 | 正常退出，保护层与唤醒请求均释放 |

完整应用的界面、输入和多显示器验收记录见 [verification/README.md](verification/README.md)。上面的结果不代表已经逐一验证每一种自动化、远程软件、显卡和未来系统版本。请在你实际使用的工具中确认截图、点击、输入和再次截图都正常后，再长期离席使用。

当前尚未由人站在显示器前确认实体屏幕显示效果，也没有进行独立的 UU 实时远控会话验收。远程采集会排除壁纸，因此远程桌面截图本身不能代替实体屏幕观察。

壁纸保护层可以穿透截图，但你主动打开的密码对话框会正常显示在截图和远程画面中，便于远程输入密码。

## 安装与构建

构建要求：macOS、Xcode Command Line Tools、Swift 5.9 或更新版本。部署目标为 macOS 14.0；当前实际运行验证环境为 macOS 15.5。

```bash
swift test
bash scripts/build-app.sh --universal
bash scripts/package.sh
```

产物：

- `dist/StillHere.app`：Apple Silicon + Intel 通用应用。
- `dist/StillHere-0.1.0-mac.zip`：应用压缩包。
- `dist/StillHere-0.1.0-mac.dmg`：拖入 Applications 的安装映像。
- `dist/SHA256SUMS.txt`：安装包校验值。

当前构建使用本地 ad-hoc 签名，尚未经过 Apple 公证。源代码构建不需要 Apple 开发者账号。

## 诊断与命令行

```bash
bash scripts/diagnose.sh
dist/StillHere.app/Contents/MacOS/StillHere --status
dist/StillHere.app/Contents/MacOS/StillHere --shield
dist/StillHere.app/Contents/MacOS/StillHere --unlock
```

`--unlock` 只打开密码对话框，不绕过密码。`--quit` 在防窥状态下同样要求密码。

开发时可以用 `STILLHERE_DATA_DIR` 指向隔离目录，避免修改日常配置。`--fixture` 会打开独立的自动化验证窗口，`--close-fixture` 关闭它；这些窗口不会出现在正常使用流程中。

## 本地数据与保护边界

数据保存在 `~/Library/Application Support/StillHere/`。退出密码使用独立随机盐和 PBKDF2-HMAC-SHA256（310,000 次迭代）保存校验值，文件权限为 `0600`。应用不保存明文密码，不上传图片、截图或密码，也不连接服务器。

StillHere 提供离席画面遮挡和正常退出验证。它保持登录桌面可操作，因此不能替代系统锁屏对有物理访问权限的人的隔离；有权限强制结束进程的人仍可以移除遮挡。

## 壁纸

默认的“我司雇我在”水豚梗图由内置 imagegen 生成，提示词保存在 [assets/wallpaper-prompt.txt](assets/wallpaper-prompt.txt)。可以在应用内换成自己的 PNG、JPEG、HEIC 或 GIF 图片；静态 PNG 为当前默认交付格式。

## 原理参考

- [Apple：ScreenCaptureKit 的采集过滤与遮挡窗口](https://developer.apple.com/videos/play/wwdc2022/10155/)
- [Apple：窗口鼠标穿透](https://developer.apple.com/documentation/appkit/nswindow/ignoresmouseevents)
- [Apple：窗口共享属性的当前状态](https://developer.apple.com/documentation/appkit/nswindow/sharingtype-swift.enum)
- [Electron：当前 macOS 的采集排除兼容性说明](https://www.electronjs.org/docs/latest/api/browser-window#winsetcontentprotectionenable-macos-windows)

MIT License.
