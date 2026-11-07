import AppKit
import Carbon
import StillHereCore
import UniformTypeIdentifiers

let appVersion = "0.2.0"
let commandNotification = Notification.Name("dev.0xzohar.stillhere.command")

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let storage: AppStorage
    private let overlay = OverlayController()
    private var preferences: Preferences
    private var credential: PasswordCredential?
    private var credentialError: String?
    private var statusItem: NSStatusItem!
    private var enterItem: NSMenuItem!
    private var settingsItem: NSMenuItem!
    private var statusLabel: NSMenuItem!
    private var preferencesWindow: PreferencesWindow?
    private var authPanel: AuthenticationPanel?
    private var fixture: AutomationFixture?
    private var throttle = AuthenticationThrottle()
    private var hotKey: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var localShortcutMonitor: Any?
    private var lastShortcutTime = Date.distantPast
    private var shortcutPressCount = 0
    private var commandObserver: NSObjectProtocol?
    private var allowTermination = false
    private var initiallyShowFixture: Bool
    private var displayUpdate: DispatchWorkItem?
    private var diagnostic: Process?

    init(storage: AppStorage, fixture: Bool) {
        self.storage = storage
        preferences = storage.loadPreferences()
        initiallyShowFixture = fixture
        super.init()
        do { credential = try storage.loadCredential() }
        catch { credentialError = error.localizedDescription }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureMenu()
        registerHotKey()
        overlay.onChange = { [weak self] in self?.updateState() }
        NotificationCenter.default.addObserver(self, selector: #selector(displaysChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(displaysChanged),
            name: NSWorkspace.didWakeNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(displaysChanged),
            name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
        commandObserver = DistributedNotificationCenter.default().addObserver(
            forName: commandNotification, object: storage.commandScope, queue: .main) { [weak self] note in
                guard let action = note.userInfo?["action"] as? String else { return }
                DispatchQueue.main.async { self?.handleCommand(action) }
            }
        updateState()
        if let credentialError { alert("密码配置异常", credentialError) }
        else if credential == nil { showPreferences() }
        if initiallyShowFixture { showFixture() }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if allowTermination || !overlay.isActive { return .terminateNow }
        requestUnlock(quit: true)
        return .terminateCancel
    }

    func applicationWillTerminate(_ notification: Notification) {
        overlay.hide()
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let eventHandler { RemoveEventHandler(eventHandler) }
        if let localShortcutMonitor { NSEvent.removeMonitor(localShortcutMonitor) }
        if let commandObserver { DistributedNotificationCenter.default().removeObserver(commandObserver) }
        publishStatus(running: false)
    }

    private func configureMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let menu = NSMenu()
        menu.delegate = self
        statusLabel = NSMenuItem(title: "在场 · 桌面正常显示", action: nil, keyEquivalent: "")
        menu.addItem(statusLabel)
        menu.addItem(.separator())
        enterItem = item("开启隐私壁纸", #selector(toggleProtection))
        enterItem.keyEquivalent = "p"
        enterItem.keyEquivalentModifierMask = [.control, .option, .command]
        menu.addItem(enterItem)
        settingsItem = item("壁纸与退出密码…", #selector(settingsClicked))
        menu.addItem(settingsItem)
        menu.addItem(.separator())
        menu.addItem(item("检查采集兼容性…", #selector(runDiagnostics)))
        menu.addItem(item("关于在场…", #selector(about)))
        menu.addItem(.separator())
        menu.addItem(item("退出在场", #selector(quitClicked)))
        statusItem.menu = menu
    }

    private func item(_ title: String, _ action: Selector) -> NSMenuItem {
        let result = NSMenuItem(title: title, action: action, keyEquivalent: "")
        result.target = self
        return result
    }

    func menuWillOpen(_ menu: NSMenu) { updateState() }

    private func updateState() {
        guard statusItem != nil else { return }
        let active = overlay.isActive
        statusItem.button?.image = NSImage(systemSymbolName: active ? "eye.slash.fill" : "eye", accessibilityDescription: "在场防窥")
        statusItem.button?.title = active ? " 在场 · 防窥中" : " 在场"
        statusItem.button?.toolTip = active ? "隐私壁纸已开启，自动化继续工作。⌃⌥⌘P 输入密码退出。" : "⌃⌥⌘P 开启隐私壁纸"
        statusLabel.title = active ? "在场 · \(overlay.windows.count) 块屏幕受保护" : "在场 · 桌面正常显示"
        enterItem.title = active ? "输入密码，解除防窥…" : "开启隐私壁纸"
        settingsItem.isEnabled = !active
        publishStatus()
    }

    private func wallpaper() -> NSImage {
        if let name = preferences.wallpaperFilename,
           name == URL(fileURLWithPath: name).lastPathComponent,
           let image = NSImage(contentsOf: storage.directory.appendingPathComponent(name)) { return image }
        return BuiltInWallpaper.find(preferences.builtInWallpaperID ?? "capybara")?.image
            ?? BuiltInWallpaper.find("capybara")?.image ?? NSImage(size: NSSize(width: 1600, height: 1000))
    }

    @objc private func toggleProtection() {
        if overlay.isActive { requestUnlock() } else { shield() }
    }

    private func shield() {
        do {
            guard hotKey != nil, eventHandler != nil else {
                alert("退出快捷键不可用", "⌃⌥⌘P 可能被其他应用占用。为保证能随时请求密码退出，本次没有开启防窥。")
                return
            }
            guard let value = try storage.loadCredential() else { showPreferences(); return }
            try value.validate()
            credential = value
            guard !overlay.isActive else { return }
            guard hasCurrentCompatibility else {
                startDiagnostics(activateAfter: true)
                return
            }
            preferencesWindow?.close()
            try overlay.show(image: wallpaper(), keepAwake: preferences.keepAwake)
        } catch { alert("无法开启防窥", error.localizedDescription) }
    }

    private func requestUnlock(quit: Bool = false) {
        guard overlay.isActive else {
            if quit { NSApp.terminate(nil) }
            return
        }
        if authPanel != nil { authPanel?.present(); return }
        let panel = AuthenticationPanel(quit: quit)
        panel.verify = { [weak self] password in
            guard let self else { return "应用暂不可用，请重试。" }
            let delay = self.throttle.remaining()
            if delay > 0 { return "尝试次数较多，请 \(Int(ceil(delay))) 秒后再试。" }
            do {
                guard let credential = try self.storage.loadCredential() else { return "退出密码配置丢失。" }
                guard try credential.matches(password) else {
                    self.throttle.failed()
                    self.publishStatus()
                    return "密码不正确，屏幕仍受保护。"
                }
                self.throttle.succeeded()
                return nil
            } catch { return error.localizedDescription }
        }
        panel.didAuthenticate = { [weak self] in
            guard let self else { return }
            self.authPanel = nil
            self.overlay.hide()
            if quit { self.allowTermination = true; NSApp.terminate(nil) }
        }
        panel.didCancel = { [weak self] in self?.authPanel = nil; self?.publishStatus() }
        authPanel = panel
        publishStatus()
        panel.present()
    }

    @objc private func settingsClicked() { if !overlay.isActive { showPreferences() } }

    private func showPreferences() {
        if preferencesWindow == nil {
            let controller = PreferencesWindow()
            controller.enableProtection = { [weak self] in self?.shield() }
            controller.chooseWallpaper = { [weak self] in self?.chooseWallpaper() }
            controller.resetWallpaper = { [weak self] in
                guard let self else { return }
                self.preferences.wallpaperFilename = nil
                self.preferences.builtInWallpaperID = nil
                self.savePreferences()
                self.preferencesWindow?.updateImage(self.wallpaper(), selectedID: "capybara")
            }
            controller.chooseBuiltIn = { [weak self] id in
                guard let self, let item = BuiltInWallpaper.find(id), item.image != nil else { return }
                var next = self.preferences
                next.wallpaperFilename = nil
                next.builtInWallpaperID = id
                do {
                    try self.storage.save(next, filename: "preferences.json")
                    self.preferences = next
                    self.preferencesWindow?.updateImage(self.wallpaper(), selectedID: id)
                } catch { self.alert("保存设置失败", error.localizedDescription) }
            }
            controller.changeKeepAwake = { [weak self] value in
                guard let self else { return }
                self.preferences.keepAwake = value
                self.savePreferences()
            }
            controller.savePassword = { [weak self] current, password, confirmation in
                guard let self else { return "应用暂不可用。" }
                guard password == confirmation else { return "两次输入的新密码不一致。" }
                do {
                    if let existing = try self.storage.loadCredential(), !(try existing.matches(current)) {
                        return "当前密码不正确。"
                    }
                    let value = try PasswordCredential(password: password)
                    try self.storage.saveCredential(value)
                    self.credential = value
                    self.updateState()
                    return nil
                } catch { return error.localizedDescription }
            }
            preferencesWindow = controller
        }
        let selectedID = preferences.wallpaperFilename == nil ? (preferences.builtInWallpaperID ?? "capybara") : nil
        preferencesWindow?.present(image: wallpaper(), keepAwake: preferences.keepAwake, configured: credential != nil, selectedID: selectedID)
    }

    private func chooseWallpaper() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .heic, .gif]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "选择显示在所有屏幕上的隐私图片。"
        guard panel.runModal() == .OK, let source = panel.url else { return }
        do {
            let size = try source.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard size <= 30 * 1024 * 1024, let image = NSImage(contentsOf: source),
                  image.size.width > 0, image.size.height > 0 else {
                alert("无法使用这张图片", "请选择小于 30 MB 的有效图片。"); return
            }
            let filename = "wallpaper-\(UUID().uuidString).\(source.pathExtension.lowercased())"
            let destination = storage.directory.appendingPathComponent(filename)
            try storage.prepare()
            try FileManager.default.copyItem(at: source, to: destination)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: destination.path)
            let previous = preferences.wallpaperFilename
            preferences.wallpaperFilename = filename
            preferences.builtInWallpaperID = nil
            try storage.save(preferences, filename: "preferences.json")
            if let previous, previous.hasPrefix("wallpaper-"), previous == URL(fileURLWithPath: previous).lastPathComponent {
                try? FileManager.default.removeItem(at: storage.directory.appendingPathComponent(previous))
            }
            preferencesWindow?.updateImage(image, selectedID: nil)
        } catch { alert("保存图片失败", error.localizedDescription) }
    }

    private func savePreferences() {
        do { try storage.save(preferences, filename: "preferences.json") }
        catch { alert("保存设置失败", error.localizedDescription) }
    }

    @objc private func displaysChanged() {
        guard overlay.isActive else { return }
        displayUpdate?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.overlay.isActive else { return }
            do { try self.overlay.show(image: self.wallpaper(), keepAwake: self.preferences.keepAwake) }
            catch { self.publishStatus() }
        }
        displayUpdate = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: work)
    }

    private func registerHotKey() {
        var event = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let callback: EventHandlerUPP = { _, _, context in
            guard let context else { return OSStatus(eventNotHandledErr) }
            let delegate = Unmanaged<AppDelegate>.fromOpaque(context).takeUnretainedValue()
            DispatchQueue.main.async { delegate.shortcutInvoked() }
            return noErr
        }
        let context = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetEventDispatcherTarget(), callback, 1, &event, context, &eventHandler)
        let id = EventHotKeyID(signature: 0x53544852, id: 1)
        RegisterEventHotKey(UInt32(kVK_ANSI_P), UInt32(controlKey | optionKey | cmdKey), id,
                           GetEventDispatcherTarget(), 0, &hotKey)
        // Some automation tools deliver keys to the application rather than the
        // global HID stream. Handle the explicit shortcut locally as well.
        localShortcutMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let flags = event.modifierFlags
            if event.keyCode == UInt16(kVK_ANSI_P), flags.contains([.control, .option, .command]) {
                DispatchQueue.main.async { self?.shortcutInvoked() }
                return nil
            }
            return event
        }
    }

    private func shortcutInvoked() {
        let now = Date()
        guard now.timeIntervalSince(lastShortcutTime) > 0.25 else { return }
        lastShortcutTime = now
        shortcutPressCount += 1
        toggleProtection()
        publishStatus()
    }

    private func handleCommand(_ action: String) {
        switch action {
        case "shield": shield()
        case "unlock": requestUnlock()
        case "settings": settingsClicked()
        case "quit": quitClicked()
        case "fixture": showFixture()
        case "close-fixture": fixture?.close(); fixture = nil
        case "diagnose": runDiagnostics()
        default: break
        }
    }

    private func showFixture() {
        if fixture == nil { fixture = AutomationFixture() }
        fixture?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        fixture?.window?.makeKeyAndOrderFront(nil)
    }

    @objc private func quitClicked() {
        if overlay.isActive { requestUnlock(quit: true) } else { NSApp.terminate(nil) }
    }

    @objc private func about() {
        alert("在场 · StillHere \(appVersion)",
              "人可以离席，工作继续在场。\n\n默认快捷键：⌃⌥⌘P\n防窥层对键鼠透明，解除防窥需要应用密码。\n\n本工具用于遮挡物理显示器。采集排除的效果取决于 macOS 版本和读屏方式，首次使用及系统升级后请验证你的实际自动化。")
    }

    @objc private func runDiagnostics() { startDiagnostics(activateAfter: false) }

    private var hasCurrentCompatibility: Bool {
        guard let data = try? Data(contentsOf: storage.directory.appendingPathComponent("compatibility.json")),
              let value = try? JSONDecoder().decode(CaptureCompatibility.self, from: data) else { return false }
        return value.isUsable(on: ProcessInfo.processInfo.operatingSystemVersionString)
    }

    private func startDiagnostics(activateAfter: Bool) {
        guard !overlay.isActive else { alert("先解除防窥", "兼容性检查需要显示短时测试色块，请先解除防窥再运行。"); return }
        guard diagnostic == nil else { return }
        let helper = Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/capture_probe")
        guard FileManager.default.isExecutableFile(atPath: helper.path) else {
            alert("诊断工具不可用", "开发环境可运行 scripts/diagnose.sh。正式应用内包含诊断工具。"); return
        }
        let process = Process()
        process.executableURL = helper
        let output = storage.directory.appendingPathComponent("Diagnostics/\(Int(Date().timeIntervalSince1970))")
        process.arguments = [output.path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        process.terminationHandler = { [weak self] process in
            DispatchQueue.main.async {
                guard let self else { return }
                self.diagnostic = nil
                if process.terminationStatus == 77 {
                    let alert = NSAlert()
                    alert.messageText = "先验证本机的采集兼容性"
                    alert.informativeText = "首次开启需要验证壁纸不会挡住自动化截图。检查仅采集角落测试区域，不上传截图。\n\n也可以在已有录屏权限的终端运行：\n/Applications/StillHere.app/Contents/MacOS/StillHere --diagnose\n这样无需给在场新增录屏权限。"
                    alert.addButton(withTitle: "请求诊断录屏权限")
                    alert.addButton(withTitle: "暂不开启")
                    NSApp.activate(ignoringOtherApps: true)
                    if alert.runModal() == .alertFirstButtonReturn {
                        _ = CGRequestScreenCaptureAccess()
                        self.alert("权限生效后重新检查", "请按系统提示允许录屏，然后重新打开在场，再开启防窥。")
                    }
                    return
                }
                guard let data = try? Data(contentsOf: output.appendingPathComponent("results.json")),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    self.alert("诊断未完成", "请重新运行检查。防窥没有自动开启。"); return
                }
                guard let record = CaptureCompatibility.fromProbe(json, currentBuild: ProcessInfo.processInfo.operatingSystemVersionString) else {
                    self.alert("诊断结果不完整", "本次没有开启防窥，请重新检查。")
                    return
                }
                let passed = record.isUsable(on: ProcessInfo.processInfo.operatingSystemVersionString)
                do { try self.storage.save(record, filename: "compatibility.json") }
                catch { self.alert("无法保存兼容性结果", error.localizedDescription); return }
                if passed && activateAfter { self.shield(); return }
                self.alert(passed ? "两种采集检查通过" : "存在采集兼容性问题",
                    passed ? "普通截图与 ScreenCaptureKit 均能看到遮挡层下面的画面。请再验证你实际使用的自动化。" : "当前环境至少有一种采集未通过，请先检查你的实际读屏工具。")
            }
        }
        do { try process.run(); diagnostic = process }
        catch { alert("无法运行诊断", error.localizedDescription) }
    }

    private func publishStatus(running: Bool = true) {
        let state: [String: Any] = [
            "version": appVersion, "running": running, "pid": ProcessInfo.processInfo.processIdentifier,
            "protected": overlay.isActive, "screenCount": NSScreen.screens.count,
            "windows": overlay.windowInfo, "passwordConfigured": credential != nil,
            "authenticationDialogOpen": authPanel != nil, "failedAuthenticationAttempts": throttle.failures,
            "captureCompatibilityVerified": hasCurrentCompatibility,
            "shortcutRegistered": hotKey != nil && eventHandler != nil,
            "shortcutPressCount": shortcutPressCount,
            "powerAssertionCount": overlay.powerAssertionCount,
            "updatedAt": ISO8601DateFormatter().string(from: Date())
        ]
        do {
            try storage.prepare()
            let url = storage.directory.appendingPathComponent("runtime.json")
            try JSONSerialization.data(withJSONObject: state, options: [.prettyPrinted, .sortedKeys]).write(to: url, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        } catch { NSLog("StillHere could not save runtime status: %@", error.localizedDescription) }
    }

    private func alert(_ title: String, _ detail: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = detail
        alert.addButton(withTitle: "好")
        if overlay.isActive {
            alert.window.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 4)
        }
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}
