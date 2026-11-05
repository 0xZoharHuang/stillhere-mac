import AppKit

final class AuthenticationPanel: NSWindowController, NSWindowDelegate {
    private let password = NSSecureTextField()
    private let errorLabel = NSTextField(wrappingLabelWithString: " ")
    var verify: ((String) -> String?)?
    var didAuthenticate: (() -> Void)?
    var didCancel: (() -> Void)?
    private var completed = false

    init(quit: Bool) {
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 420, height: 230),
                            styleMask: [.titled, .closable], backing: .buffered, defer: false)
        panel.title = quit ? "退出在场" : "回到桌面"
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 3)
        panel.sharingType = .readOnly // Remote users must be able to see this explicit dialog.
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        super.init(window: panel)
        panel.delegate = self
        let heading = NSTextField(labelWithString: quit ? "输入密码，退出在场" : "输入密码，解除防窥")
        heading.font = .systemFont(ofSize: 20, weight: .semibold)
        let detail = NSTextField(wrappingLabelWithString: "验证完成前，隐私壁纸会持续保护屏幕。")
        detail.textColor = .secondaryLabelColor
        password.placeholderString = "退出密码"
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
        let buttons = NSStackView(views: [cancel, accept])
        buttons.orientation = .horizontal
        buttons.alignment = .centerY
        let stack = NSStackView(views: [heading, detail, password, errorLabel, buttons])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        panel.contentView!.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: panel.contentView!.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: panel.contentView!.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: panel.contentView!.topAnchor, constant: 24),
            password.widthAnchor.constraint(equalTo: stack.widthAnchor),
            errorLabel.widthAnchor.constraint(equalTo: stack.widthAnchor)
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
