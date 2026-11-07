# 在场 · StillHere for Windows

Windows 原生托盘版本，使用系统自带的 .NET Framework 4.8，无需安装新的 .NET SDK。最低系统为 Windows 10 2004 / build 19041。

当前版本为 Windows 0.2.0 Beta：快捷键直接开启和退出，不再要求密码。Windows 10 / build 19045 的原生输入验收与安装读回见[验收记录](../verification/application-windows10-v0.2.0.json)。

旧版记录见 [application-windows10.json](../verification/application-windows10.json) 和 [application-windows-server2022.json](../verification/application-windows-server2022.json)。

## 构建

在 Windows 命令行运行：

```bat
windows\build.cmd
```

产物为 `dist\windows\StillHere.exe`。默认壁纸内嵌在单个 EXE 中。

## 使用

将开箱包完整解压后打开 EXE；在「选择壁纸」中可选择同包 `Wallpapers` 文件夹内的 8 张图片。用 **Ctrl + Alt + Shift + P** 显式开启或退出。首次开启先验证屏幕采集能排除保护层，并能看到下层画面的更新；失败时不会铺满屏幕。

保护层使用 `WDA_EXCLUDEFROMCAPTURE`、不激活的 Win32 原生窗口和鼠标穿透。壁纸窗口不包含交互控件，并在创建时禁用键盘输入。再次按快捷键直接返回桌面，退出应用也会移除壁纸。普通点击、输入和移动鼠标不会解除保护。

旧版本的密码校验文件会保留在本机，但此版本不会读取或使用它。

## 检查

```bat
StillHere.exe --core-self-test --output core-tests.json
StillHere.exe --diagnose --output capture-check.json
StillHere.exe --status --output runtime-check.json
```

`--core-self-test` 不操作桌面；`--diagnose` 在屏幕角落显示短时测试色块，用带 CAPTUREBLT 的 GDI 采集普通遮挡、排除遮挡和下层颜色变化。只有阳性对照、排除和实时更新都符合预期才通过。

检查需要正常的登录桌面。第三方屏保覆盖测试色块时，应用会拒绝开启保护；应先正常退出该屏保再检查。应用不会自动结束其他程序或更改系统锁屏设置。

`--qa` 为原生自动化验收创建临时独立配置并打开测试窗口；目录信息保存在当前用户的 `StillHere\qa-session.json`。它不修改正常配置，退出后清理自己的临时配置。该入口仅用于开发验证。

`--qa-run-ui --output ui-acceptance.json` 会在独立临时配置中使用真正的 Windows `SendInput` 验证快捷键开启、点击输入、快捷键退出、再次开启和退出应用。每次发送输入前核对窗口归属；55 秒看门狗在失败时撤掉自己的测试保护层。报告不包含用户数据。

该工具保持登录桌面可操作，适合离席遮挡，不替代 Windows 锁屏对物理访问的隔离。安装包尚未进行 Windows 代码签名。其他采集实现仍需通过实际截图、点击和输入流程确认。

参考：[SetWindowDisplayAffinity](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-setwindowdisplayaffinity)、[SetWindowPos 的不激活显示参数](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-setwindowpos)、[Layered windows](https://learn.microsoft.com/en-us/windows/win32/winmsg/window-features#layered-windows)。
