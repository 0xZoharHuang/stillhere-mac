import AppKit

final class AuthenticationPanel: NSWindowController, NSWindowDelegate {
    private let password = NSSecureTextField()
    private let errorLabel = NSTextField(wrappingLabelWithString: " ")
    var verify: ((String) -> String?)?
    var didAuthenticate: (() -> Void)?
    var didCancel: (() -> Void)?
    private var completed = false

    init(quit: Bool) {
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 440, height: 252),
                            styleMask: [.titled, .closable], backing: .buffered, defer: false)
        panel.title = quit ? "退出在场" : "回到桌面"
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 3)
        panel.sharingType = .readOnly // Remote users must be able to see this explicit dialog.
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        super.init(window: panel)
        panel.delegate = self
        let symbol = NSImageView(image: NSImage(systemSymbolName: "lock.shield.fill", accessibilityDescription: nil) ?? NSImage())
        symbol.contentTintColor = .controlAccentColor
        symbol.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 23, weight: .medium)
        symbol.widthAnchor.constraint(equalToConstant: 38).isActive = true
        let heading = NSTextField(labelWithString: quit ? "退出在场" : "欢迎回来")
        heading.font = .systemFont(ofSize: 21, weight: .semibold)
        let detail = NSTextField(wrappingLabelWithString: quit ? "输入退出密码以关闭应用。" : "输入退出密码，返回你的桌面。")
        detail.textColor = .secondaryLabelColor
        detail.font = .systemFont(ofSize: 13)
        let titles = NSStackView(views: [heading, detail])
        titles.orientation = .vertical
        titles.alignment = .leading
        titles.spacing = 5
        let header = NSStackView(views: [symbol, titles])
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = 12
        password.placeholderString = "退出密码"
        password.controlSize = .large
        password.setAccessibilityLabel("退出密码")
        password.identifier = NSUserInterfaceItemIdentifier("unlockPassword")
        password.target = self
        password.action = #selector(submit)
        errorLabel.textColor = .systemRed
        errorLabel.font = .systemFont(ofSize: 12)
        let cancel = NSButton(title: "取消", target: self, action: #selector(cancel))
        cancel.bezelStyle = .rounded
        cancel.keyEquivalent = "\u{1b}"
        let accept = NSButton(title: quit ? "验证并退出" : "解除防窥", target: self, action: #selector(submit))
        accept.bezelStyle = .rounded
        accept.keyEquivalent = "\r"
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let buttons = NSStackView(views: [spacer, cancel, accept])
        buttons.orientation = .horizontal
        buttons.alignment = .centerY
        buttons.spacing = 8
        let stack = NSStackView(views: [header, password, errorLabel, buttons])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        panel.contentView!.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: panel.contentView!.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: panel.contentView!.trailingAnchor, constant: -28),
            stack.topAnchor.constraint(equalTo: panel.contentView!.topAnchor, constant: 26),
            password.widthAnchor.constraint(equalTo: stack.widthAnchor),
            errorLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),
            buttons.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
        panel.center()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func present() {
        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        window?.makeFirstResponder(password)
    }

    @objc private func submit() {
        let candidate = password.stringValue
        password.stringValue = ""
        guard let verify else {
            errorLabel.stringValue = "验证暂不可用，屏幕仍受保护。"
            return
        }
        if let message = verify(candidate) {
            errorLabel.stringValue = message
            window?.makeFirstResponder(password)
            return
        }
        completed = true
        let completion = didAuthenticate
        close()
        completion?()
    }

    @objc private func cancel() { close() }
    func windowWillClose(_ notification: Notification) { if !completed { didCancel?() } }
}
