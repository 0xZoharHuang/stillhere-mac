# Verification evidence

Runtime evidence must come from the packaged application and an independent capture/input path. A successful unit test or a screenshot filtered by our own capture code is insufficient to qualify the product.

## Mechanism probe

`research/capture_probe.m` creates two small, nonactivating, click-through windows: a green target and a magenta cover. It captures a normal cover, captures with explicit ScreenCaptureKit exclusion as a reference, then sets only the cover's sharing type to `none` and captures again with both a legacy capture API and an unfiltered ScreenCaptureKit capture. No keyboard or mouse input is injected. A 24-second watchdog exits on stalls.

All saved images are cropped to the test patch. Actual desktop pixels are not intentionally stored. The window focus check compares the frontmost application's process before and after the probe.

The macOS 15.5 / 24F74 results are in [mechanism-macos15.5.json](mechanism-macos15.5.json) and [mechanism-external-display-macos15.5.json](mechanism-external-display-macos15.5.json). The high-density built-in display and the external display were checked separately. Both normal-capture controls show the magenta overlay; both protected captures show the green target. The explicit-exclusion reference also shows the target, and the frontmost application stays unchanged.

## Application acceptance

The redesigned macOS 0.2.0 application has a separate record at [application-macos15.5-v0.2.0.json](application-macos15.5-v0.2.0.json): installed-bundle, ZIP and read-only DMG file checks; visual inspection of overview, library, preferences and unlock; gallery selection persistence; legacy preference migration; and native button, shortcut and authentication behavior on two displays using an isolated test profile. The existing same-build capture qualification was reused. The earlier 0.1.0 record below remains historical evidence.

[distribution-macos0.2.0.json](distribution-macos0.2.0.json) records a fresh download from the public 0.2.0 Beta release; both installers and the checksum file match the locally verified files.

The final runtime record is [application-macos15.5.json](application-macos15.5.json). It identifies the packaged build, screen count, independent automation actions, password behavior, and installation readback. Unverified items remain explicitly listed; compiling an Intel slice does not establish runtime acceptance on an Intel Mac.

Native acceptance used the installed application and the CUA native app control path: the tool captured the real fixture under two active privacy windows, clicked the field, entered a new phrase, clicked the record button, and captured the updated text and live clock. The explicit shortcut enabled privacy and then opened the password dialog. A wrong password and cancellation left both windows active; a protected quit request required authentication, and the correct password exited and released power assertions. Normal relaunch kept privacy off. The settings window and default image preview were visually checked at the intended 590-point width.

The final preferences-only layout correction did not alter capture, input, or authentication code. Its UI was inspected separately after installation. At that validation point, the application was left running in the menu bar with privacy off and no authentication dialog open.

The user subsequently confirmed in conversation, while in front of the Mac, that the privacy wallpaper appeared normal and the password returned to the desktop. This is a user-reported physical-panel observation, not a separate visual record for each display. A live UU remote session, other macOS versions, and Intel hardware remain unverified. These are separate from the completed native automation check.

Raw per-user profiles, password verifiers, local runtime state, and desktop screenshots are excluded from Git. Unit tests independently check a PBKDF2 reference vector, wrong-password rejection, randomized salts, private file permissions, configuration corruption, and retry delays.

## Distribution readback

[distribution.json](distribution.json) records the ZIP and DMG checksums. Both were unpacked or mounted read-only, and every application-bundle file matched the built and installed copy. Deep, strict code-signature verification passed. The DMG's Applications shortcut points to `/Applications`, and the image was detached after the check. The build is ad-hoc signed and is not Apple-notarized.

## Windows desktop acceptance

[application-windows-server2022.json](application-windows-server2022.json) records the final Windows Beta on a GitHub Windows Server 2022 / build 20348 interactive desktop (session 2). Seven core checks passed. Both the standalone and first-enable capture probes passed the ordinary-cover positive control, exclusion, live-update and unchanged-foreground checks.

The actual `SendInput` journey passed shortcut activation, typing and clicking the real fixture while protected, rejection of a wrong password, cancellation that kept protection, and a correct password that exited and released protection. The ZIP contains the exact EXE tested in that run; the packaged executable hash matches the test environment record. No screenshot exclusion list is supplied by the input test.

[application-windows10.json](application-windows10.json) records the final published EXE on the authorized Windows 10 / build 19045 host. Both downloaded ZIP and EXE matched the published release hashes. The complete native input and password journey passed with exit code 0, including unchanged foreground during first-enable qualification. The same EXE was installed per user and a desktop shortcut was created; startup left protection off. The user's first-run password setup is tracked separately.

The latest readback in that record verifies that the installed executable still matches the tested release, the normal application process is running with protection off and its shortcut registered, and no temporary QA process remains. The user's personal exit password was not yet configured at the time of that readback.

Earlier results are preserved separately in that record: managed forms took focus in a previous build, and third-party ScreenSaverPlayer instances interfered with capture in the final build. Those failures were rejected by the qualification gate. After only the observed screen-saver processes were ended, the unchanged published EXE passed the full Windows 10 journey. No system account or lock policy was changed.

No personal password profile is shipped in the public package. Physical-panel observation and an independent UU video and remote input journey with the final Windows build remain unverified. These limits are separate from the completed native desktop input tests.

[distribution-windows.json](distribution-windows.json) records a fresh download from the published Windows Beta release. Its ZIP, extracted EXE, and checksum file all match the package and executable from the successful desktop acceptance run.

## Reproduce

```bash
swift test
bash scripts/build-app.sh --universal
bash scripts/diagnose.sh
```

For a real automation check, open the application with `--fixture`, enable privacy, and use the actual automation tool to read the fixture, click its input, enter a new phrase, click the record button, and capture the changed result. Verify that a wrong exit password leaves the mask active, while the correct password removes it. Confirm the physical wallpaper separately by local observation.
