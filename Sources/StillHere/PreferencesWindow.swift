import AppKit

private final class WallpaperPreview: NSImageView {
    override var intrinsicContentSize: NSSize { NSSize(width: NSView.noIntrinsicMetric, height: 190) }
}

final class PreferencesWindow: NSWindowController {
    private let preview = WallpaperPreview()
    private let current = NSSecureTextField()
    private let password = NSSecureTextField()
    private let confirmation = NSSecureTextField()
    private let feedback = NSTextField(wrappingLabelWithString: " ")
    private let awake = NSButton(checkboxWithTitle: "防窥期间保持电脑和显示器唤醒", target: nil, action: nil)
    private let passwordHeading = NSTextField(labelWithString: "退出密码")
    var chooseWallpaper: (() -> Void)?
    var resetWallpaper: (() -> Void)?
    var savePassword: ((String, String, String) -> String?)?
    var changeKeepAwake: ((Bool) -> Void)?

    init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 590, height: 700),
                              styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "在场 · StillHere"
        window.isReleasedWhenClosed = false
        window.contentMinSize = NSSize(width: 590, height: 700)
        window.contentMaxSize = NSSize(width: 590, height: 700)
        super.init(window: window)
        let title = NSTextField(labelWithString: "人可以离席，工作继续在场。")
        title.font = .systemFont(ofSize: 23, weight: .semibold)
        let subtitle = NSTextField(wrappingLabelWithString: "显示器看壁纸，自动化继续看桌面、用键鼠。")
        subtitle.textColor = .secondaryLabelColor
        preview.imageScaling = .scaleProportionallyUpOrDown
        preview.wantsLayer = true
        preview.layer?.cornerRadius = 12
        preview.layer?.masksToBounds = true
        preview.layer?.backgroundColor = NSColor(calibratedRed: 0.98, green: 0.94, blue: 0.86, alpha: 1).cgColor
        let choose = NSButton(title: "选择图片…", target: self, action: #selector(choose))
        let reset = NSButton(title: "使用默认梗图", target: self, action: #selector(reset))
        choose.bezelStyle = .rounded; reset.bezelStyle = .rounded
        let imageButtons = NSStackView(views: [choose, reset])
        imageButtons.orientation = .horizontal
        passwordHeading.font = .systemFont(ofSize: 15, weight: .semibold)
        current.placeholderString = "当前密码（首次设置留空）"
        current.setAccessibilityLabel("当前密码")
        password.placeholderString = "新密码，至少 6 位"
        password.setAccessibilityLabel("新密码")
        confirmation.placeholderString = "再输入一次新密码"
        confirmation.setAccessibilityLabel("确认新密码")
        let save = NSButton(title: "保存退出密码", target: self, action: #selector(save))
        save.bezelStyle = .rounded
        feedback.font = .systemFont(ofSize: 12)
        awake.target = self; awake.action = #selector(awakeChanged)
        let shortcut = NSTextField(labelWithString: "快捷键：⌃⌥⌘P　开启防窥 / 请求密码退出")
        shortcut.textColor = .secondaryLabelColor
        shortcut.font = .systemFont(ofSize: 12)
        let stack = NSStackView(views: [title, subtitle, preview, imageButtons, passwordHeading,
                                        current, password, confirmation, save, feedback, awake, shortcut])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 9
        stack.translatesAutoresizingMaskIntoConstraints = false
        window.contentView!.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor, constant: 26),
            stack.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor, constant: -26),
            stack.topAnchor.constraint(equalTo: window.contentView!.topAnchor, constant: 24),
            stack.widthAnchor.constraint(equalToConstant: 538),
            preview.widthAnchor.constraint(equalTo: stack.widthAnchor),
            preview.heightAnchor.constraint(equalToConstant: 190),
            current.widthAnchor.constraint(equalTo: stack.widthAnchor),
            password.widthAnchor.constraint(equalTo: stack.widthAnchor),
            confirmation.widthAnchor.constraint(equalTo: stack.widthAnchor),
            feedback.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
        window.center()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func present(image: NSImage, keepAwake: Bool, configured: Bool) {
        preview.image = image
        awake.state = keepAwake ? .on : .off
        current.isHidden = !configured
        passwordHeading.stringValue = configured ? "修改退出密码" : "先设置一个退出密码"
        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func updateImage(_ image: NSImage) { preview.image = image }
    @objc private func choose() { chooseWallpaper?() }
    @objc private func reset() { resetWallpaper?() }
    @objc private func awakeChanged() { changeKeepAwake?(awake.state == .on) }
    @objc private func save() {
        if let error = savePassword?(current.stringValue, password.stringValue, confirmation.stringValue) {
            feedback.textColor = .systemRed
            feedback.stringValue = error
        } else {
            feedback.textColor = .systemGreen
            feedback.stringValue = "退出密码已保存。可以从菜单栏开启防窥。"
            current.isHidden = false
            passwordHeading.stringValue = "修改退出密码"
        }
        current.stringValue = ""; password.stringValue = ""; confirmation.stringValue = ""
    }
}
