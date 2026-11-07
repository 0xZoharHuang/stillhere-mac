# Contributing to StillHere

Thanks for helping make stepping away from the desk a little more fun. English and Chinese are both welcome.

- For bugs, include your OS version, app version, number of displays, and the capture or remote-control tool involved. Describe what appeared on the physical display separately from what the remote tool captured. Do not attach passwords, personal screenshots, or private logs.
- For wallpaper ideas, describe the joke and provide the Chinese and English text. Contributed artwork must be your own or appropriately licensed; do not upload somebody else's meme image without permission.
- For a code change, explain the behavior and how you verified it on an actual desktop. Capture compatibility, physical display output, input behavior, and a particular remote-control app are separate checks.

Run `swift test` and `bash scripts/build-app.sh --universal` for macOS changes. Windows build and the isolated desktop acceptance workflow are documented in [windows/README.md](windows/README.md). The full-screen cover must not be enabled when its capture qualification or exit shortcut is unavailable.
