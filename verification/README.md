# Verification evidence

Runtime evidence must come from the packaged application and an independent capture/input path. A successful unit test or a screenshot filtered by our own capture code is insufficient to qualify the product.

## Mechanism probe

`research/capture_probe.m` creates two small, nonactivating, click-through windows: a green target and a magenta cover. It captures a normal cover, captures with explicit ScreenCaptureKit exclusion as a reference, then sets only the cover's sharing type to `none` and captures again with both a legacy capture API and an unfiltered ScreenCaptureKit capture. No keyboard or mouse input is injected. A 24-second watchdog exits on stalls.

All saved images are cropped to the test patch. Actual desktop pixels are not intentionally stored. The window focus check compares the frontmost application's process before and after the probe.

The macOS 15.5 / 24F74 results are in [mechanism-macos15.5.json](mechanism-macos15.5.json) and [mechanism-external-display-macos15.5.json](mechanism-external-display-macos15.5.json). The high-density built-in display and the external display were checked separately. Both normal-capture controls show the magenta overlay; both protected captures show the green target. The explicit-exclusion reference also shows the target, and the frontmost application stays unchanged.

## Application acceptance

The final runtime record is [application-macos15.5.json](application-macos15.5.json). It identifies the packaged build, screen count, independent automation actions, password behavior, and installation readback. Unverified items remain explicitly listed; compiling an Intel slice does not establish runtime acceptance on an Intel Mac.

Native acceptance used the installed application and the CUA native app control path: the tool captured the real fixture under two active privacy windows, clicked the field, entered a new phrase, clicked the record button, and captured the updated text and live clock. The explicit shortcut enabled privacy and then opened the password dialog. A wrong password and cancellation left both windows active; a protected quit request required authentication, and the correct password exited and released power assertions. Normal relaunch kept privacy off. The settings window and default image preview were visually checked at the intended 590-point width.

The final preferences-only layout correction did not alter capture, input, or authentication code. Its UI was inspected separately after installation. The application is left running in the menu bar with privacy off and no authentication dialog open.

Physical-panel appearance has not been human-confirmed. The user was not watching during the test. A live UU remote session, other macOS versions, and Intel hardware remain unverified. These are separate from the completed native automation check.

Raw per-user profiles, password verifiers, local runtime state, and desktop screenshots are excluded from Git. Unit tests independently check a PBKDF2 reference vector, wrong-password rejection, randomized salts, private file permissions, configuration corruption, and retry delays.

## Distribution readback

[distribution.json](distribution.json) records the ZIP and DMG checksums. Both were unpacked or mounted read-only, and every application-bundle file matched the built and installed copy. Deep, strict code-signature verification passed. The DMG's Applications shortcut points to `/Applications`, and the image was detached after the check. The build is ad-hoc signed and is not Apple-notarized.

## Windows desktop acceptance

[application-windows-server2022.json](application-windows-server2022.json) records the final Windows Beta on a GitHub Windows Server 2022 / build 20348 interactive desktop (session 2). Seven core checks passed. Both the standalone and first-enable capture probes passed the ordinary-cover positive control, exclusion, live-update and unchanged-foreground checks.

The actual `SendInput` journey passed shortcut activation, typing and clicking the real fixture while protected, rejection of a wrong password, cancellation that kept protection, and a correct password that exited and released protection. The ZIP contains the exact EXE tested in that run; the packaged executable hash matches the test environment record. No screenshot exclusion list is supplied by the input test.

[application-windows10.json](application-windows10.json) separately preserves the last build actually run on the authorized Windows 10 / build 19045 host. Its package and EXE matched the CI hashes; seven core checks and standalone capture passed. Its full input journey caught managed wallpaper forms taking focus when our fixture was foreground. The focus gate rejected activation, and the QA process exited with code 2 and released its own protection. This was a failed acceptance result. Raw, disabled, nonactivating Win32 windows fixed that failure in the independent Server 2022 journey; the final build still needs to be rechecked on the Windows 10 host.

No normal Windows password profile has been configured or shipped in the public package. Physical-panel observation and an independent remote input journey with the final Windows build remain unverified. These limits are separate from the completed native desktop input test.

[distribution-windows.json](distribution-windows.json) records a fresh download from the published Windows Beta release. Its ZIP, extracted EXE, and checksum file all match the package and executable from the successful desktop acceptance run.

## Reproduce

```bash
swift test
bash scripts/build-app.sh --universal
bash scripts/diagnose.sh
```

For a real automation check, open the application with `--fixture`, enable privacy, and use the actual automation tool to read the fixture, click its input, enter a new phrase, click the record button, and capture the changed result. Verify that a wrong exit password leaves the mask active, while the correct password removes it. Confirm the physical wallpaper separately by local observation.
