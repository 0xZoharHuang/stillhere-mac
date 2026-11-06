# 在场 · StillHere for Windows

Windows 原生托盘版本，使用系统自带的 .NET Framework 4.8，无需安装新的 .NET SDK。最低系统为 Windows 10 2004 / build 19041。

当前为 [0.1.0 Beta](https://github.com/0xZoharHuang/stillhere-mac/releases/tag/windows-v0.1.0)。已在 GitHub 的 Windows Server 2022 / build 20348 交互桌面上通过完整原生验收：采集排除与更新、不抢焦点、快捷键、保护下打字和点击、错误密码、取消、正确密码退出。发布包包含该流程实际测试过的同一份 EXE。

记录见 [application-windows-server2022.json](../verification/application-windows-server2022.json)。指定 Windows 10 / build 19045 电脑的最终版本复测和实体显示器观察仍待完成，见 [application-windows10.json](../verification/application-windows10.json)。

## 构建

在 Windows 命令行运行：

```bat
windows\build.cmd
```

产物为 `dist\windows\StillHere.exe`。默认壁纸内嵌在单个 EXE 中。

## 使用

打开 EXE 后从托盘设置退出密码。用 **Ctrl + Alt + Shift + P** 显式开启或请求退出。首次开启先验证屏幕采集能排除保护层，并能看到下层画面的更新；失败时不会铺满屏幕。

保护层使用 `WDA_EXCLUDEFROMCAPTURE`、不激活的 Win32 原生窗口和鼠标穿透。壁纸窗口不包含交互控件，并在创建时禁用键盘输入。密码框正常显示在远程画面中。关闭保护和受保护状态下退出应用均需要密码；普通点击、输入和移动鼠标不会解除保护。

密码校验值使用随机盐和 PBKDF2-HMAC-SHA256，存入当前用户的 LocalAppData，文件 ACL 仅允许当前用户和 SYSTEM。应用没有共享默认密码。

## 检查

```bat
StillHere.exe --core-self-test --output core-tests.json
StillHere.exe --diagnose --output capture-check.json
StillHere.exe --status --output runtime-check.json
```

`--core-self-test` 不操作桌面；`--diagnose` 在屏幕角落显示短时测试色块，用带 CAPTUREBLT 的 GDI 采集普通遮挡、排除遮挡和下层颜色变化。只有阳性对照、排除和实时更新都符合预期才通过。

`--qa` 为原生自动化验收创建临时独立配置与随机退出密码，并打开测试窗口；信息保存在当前用户的 `StillHere\qa-session.json`。它不修改正常配置，退出后清理自己的临时配置。该入口仅用于开发验证。

`--qa-run-ui --output ui-acceptance.json` 会在独立临时配置中使用真正的 Windows `SendInput` 验证快捷键、点击、输入、错误密码、取消和正确密码退出。每次发送输入前核对窗口归属；55 秒看门狗在失败时撤掉自己的测试保护层。报告不包含临时密码。

该工具保持登录桌面可操作，适合离席遮挡，不替代 Windows 锁屏对物理访问的隔离。安装包尚未进行 Windows 代码签名。其他采集实现仍需通过实际截图、点击和输入流程确认。

参考：[SetWindowDisplayAffinity](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-setwindowdisplayaffinity)、[SetWindowPos 的不激活显示参数](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-setwindowpos)、[Layered windows](https://learn.microsoft.com/en-us/windows/win32/winmsg/window-features#layered-windows)。
