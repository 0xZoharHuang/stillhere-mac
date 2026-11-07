import AppKit
import IOKit.pwr_mgt

final class PrivacyWindow: NSWindow {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class OverlayController {
    private(set) var windows: [PrivacyWindow] = []
    private var powerAssertions: [IOPMAssertionID] = []
    var isActive: Bool { !windows.isEmpty }
    var onChange: (() -> Void)?

    func show(image: NSImage, keepAwake: Bool) throws {
        guard !NSScreen.screens.isEmpty else {
            throw NSError(domain: "StillHere", code: 1, userInfo: [NSLocalizedDescriptionKey: "没有可用显示器。"])
        }
        var replacement: [PrivacyWindow] = []
        for screen in NSScreen.screens {
            let window = PrivacyWindow(contentRect: screen.frame, styleMask: .borderless,
                                       backing: .buffered, defer: false, screen: screen)
            window.title = "StillHere Privacy Wallpaper"
            window.level = .screenSaver
            window.backgroundColor = NSColor(calibratedRed: 0.98, green: 0.94, blue: 0.86, alpha: 1)
            window.isOpaque = true
            window.hasShadow = false
            window.ignoresMouseEvents = true
            window.canHide = false
            window.isReleasedWhenClosed = false
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            // Set BEFORE showing: no normal-capture frame of the wallpaper is emitted.
            // This behavior is tested per macOS/capture backend; see verification evidence.
            window.sharingType = .none
            let view = NSImageView(frame: NSRect(origin: .zero, size: screen.frame.size))
            view.image = image
            view.imageScaling = .scaleProportionallyUpOrDown
            view.imageAlignment = .alignCenter
            view.autoresizingMask = [.width, .height]
            view.animates = true
            window.contentView = view
            window.setFrame(screen.frame, display: true)
            window.orderFrontRegardless()
            replacement.append(window)
        }
        let previous = windows
        windows = replacement
        for window in previous { window.orderOut(nil); window.close() }
        updatePower(keepAwake: keepAwake)
        onChange?()
    }

    func hide() {
        let previous = windows
        windows = []
        for window in previous { window.orderOut(nil); window.close() }
        releasePower()
        onChange?()
    }

    func updatePower(keepAwake: Bool) {
        releasePower()
        guard keepAwake, isActive else { return }
        for type in [kIOPMAssertionTypePreventUserIdleSystemSleep, kIOPMAssertionTypePreventUserIdleDisplaySleep] {
            var id: IOPMAssertionID = 0
            let result = IOPMAssertionCreateWithName(type as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn), "StillHere privacy workspace" as CFString, &id)
            if result == kIOReturnSuccess { powerAssertions.append(id) }
        }
    }

    private func releasePower() {
        for id in powerAssertions { IOPMAssertionRelease(id) }
        powerAssertions.removeAll()
    }

    var powerAssertionCount: Int { powerAssertions.count }

    var windowInfo: [[String: Any]] {
        windows.map { window in
            ["windowID": window.windowNumber, "ignoresMouseEvents": window.ignoresMouseEvents,
             "canBecomeKey": window.canBecomeKey, "sharingType": window.sharingType.rawValue,
             "visible": window.isVisible, "level": window.level.rawValue,
             "x": window.frame.minX, "y": window.frame.minY,
             "width": window.frame.width, "height": window.frame.height]
        }
    }
}
