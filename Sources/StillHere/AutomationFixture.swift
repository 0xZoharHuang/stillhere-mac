import AppKit

// Explicit developer fixture; this window is never opened in the normal product flow.
final class AutomationFixture: NSWindowController {
    private let input = NSTextField()
    private let output = NSTextField(wrappingLabelWithString: "尚未记录")
    private let clock = NSTextField(labelWithString: "")
    private var timer: Timer?
    private var count = 0

    init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 300),
                              styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "StillHere Automation Laboratory"
        window.sharingType = .readOnly
        window.isReleasedWhenClosed = false
        super.init(window: window)
        let heading = NSTextField(labelWithString: "自动化验证窗口")
        heading.font = .systemFont(ofSize: 24, weight: .bold)
        let description = NSTextField(wrappingLabelWithString: "开启防窥后，截图仍应看到这个窗口；点击、输入和记录仍应生效。")
        input.placeholderString = "输入验证短语"
        input.setAccessibilityLabel("输入验证短语")
        input.identifier = NSUserInterfaceItemIdentifier("automationInput")
        let button = NSButton(title: "记录输入", target: self, action: #selector(record))
        button.bezelStyle = .rounded
        button.identifier = NSUserInterfaceItemIdentifier("recordInput")
        output.font = .monospacedSystemFont(ofSize: 15, weight: .medium)
        output.setAccessibilityLabel("验证结果")
        clock.font = .monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        clock.textColor = .secondaryLabelColor
        let stack = NSStackView(views: [heading, description, input, button, output, clock])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 18
        stack.translatesAutoresizingMaskIntoConstraints = false
        window.contentView!.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor, constant: -28),
            stack.topAnchor.constraint(equalTo: window.contentView!.topAnchor, constant: 26),
            input.widthAnchor.constraint(equalTo: stack.widthAnchor),
            output.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
        window.center()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.clock.stringValue = "实时更新：" + Date().formatted(date: .omitted, time: .standard)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
    @objc private func record() { count += 1; output.stringValue = "已记录 #\(count)：\(input.stringValue)" }
    deinit { timer?.invalidate() }
}
