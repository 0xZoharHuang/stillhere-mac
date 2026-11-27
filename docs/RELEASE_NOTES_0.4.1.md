## Mac capture fix · Mac 实时画面修复

On a MacBook Neo running macOS 26.7, both capture paths could return a pale, static patch underneath the privacy wallpaper. The new build paints the wallpaper and its margins in the content view. Before enabling privacy, it now checks that Core Graphics and unfiltered ScreenCaptureKit can see the underlying desktop change color. Previous compatibility records are checked again.

MacBook Neo 上复现了旧版防窥时采集到空白的问题。新版已在 macOS 26.7 上通过两条采集路径的实时变化检查。在 macOS 15.5 上，双屏开启防窥时，Codex 能点击、输入并读取更新后的结果。Neo 实体屏幕和 UU 远程操作仍待现场确认。

- **Mac** — Open `StillHere-0.4.1-mac-ready.dmg`, drag StillHere to Applications and double-click it. Use **Control + Option + Command + P** to toggle privacy. Double-click the app again to reopen Settings when privacy is off.
- **Windows** — Extract `StillHere-0.2.0-windows-ready.zip` and open `StillHere.exe`. Use **Ctrl + Alt + Shift + P**. The same Windows build passed a fresh native desktop test of shortcuts, typing, clicks and exit.
- Both packages include the complete 24-image bilingual collection. The Mac build has an ad-hoc signature and no Apple notarization. The Windows executable is unsigned.

[中文使用说明](https://github.com/0xZoharHuang/stillhere-mac/blob/v0.4.1/README.zh-CN.md) · [Acceptance details](https://github.com/0xZoharHuang/stillhere-mac/blob/v0.4.1/verification/acceptance-0.4.1.json)
