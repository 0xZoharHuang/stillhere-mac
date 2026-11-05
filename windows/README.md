# 在场 · StillHere for Windows

Windows 原生托盘版本，使用系统自带的 .NET Framework 4.8，无需安装新的 .NET SDK。最低系统为 Windows 10 2004 / build 19041。

当前处于构建和实际机器验收阶段；编译、核心检查、采集检查与真实远程操作分别记录，不把其中一个当作全部完成。

## 构建

在 Windows 命令行运行：

```bat
windows\build.cmd
```

产物为 `dist\windows\StillHere.exe`。默认壁纸内嵌在单个 EXE 中。

## 使用

打开 EXE 后从托盘设置退出密码。用 **Ctrl + Alt + Shift + P** 显式开启或请求退出。首次开启先验证屏幕采集能排除保护层，并能看到下层画面的更新；失败时不会铺满屏幕。

保护层使用 `WDA_EXCLUDEFROMCAPTURE`、不激活窗口和鼠标穿透。密码框正常显示在远程画面中。关闭保护和受保护状态下退出应用均需要密码；普通点击、输入和移动鼠标不会解除保护。

密码校验值使用随机盐和 PBKDF2-HMAC-SHA256，存入当前用户的 LocalAppData，文件 ACL 仅允许当前用户和 SYSTEM。应用没有共享默认密码。

## 检查

```bat
StillHere.exe --core-self-test --output core-tests.json
StillHere.exe --diagnose --output capture-check.json
StillHere.exe --status --output runtime-check.json
```

`--core-self-test` 不操作桌面；`--diagnose` 在屏幕角落显示短时测试色块，用带 CAPTUREBLT 的 GDI 采集普通遮挡、排除遮挡和下层颜色变化。只有阳性对照、排除和实时更新都符合预期才通过。

`--qa` 为原生自动化验收创建临时独立配置与随机退出密码，并打开测试窗口；信息保存在当前用户的 `StillHere\qa-session.json`。它不修改正常配置，退出后清理自己的临时配置。该入口仅用于开发验证。

该工具保持登录桌面可操作，适合离席遮挡，不替代 Windows 锁屏对物理访问的隔离。安装包尚未进行 Windows 代码签名。其他采集实现仍需通过实际截图、点击和输入流程确认。

参考：[SetWindowDisplayAffinity](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-setwindowdisplayaffinity)、[Layered windows](https://learn.microsoft.com/en-us/windows/win32/winmsg/window-features#layered-windows)。
