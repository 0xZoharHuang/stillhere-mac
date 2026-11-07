import AppKit

struct BuiltInWallpaper {
    let id: String
    let resource: String
    let title: String
    let subtitle: String
    var image: NSImage? {
        let url = Bundle.main.url(forResource: resource, withExtension: "png")
            ?? Bundle.module.url(forResource: resource, withExtension: "png")
        return url.flatMap(NSImage.init(contentsOf:))
    }
    static let all: [BuiltInWallpaper] = [
        .init(id: "capybara", resource: "ExistentialCapybara", title: "我司雇我在", subtitle: "低功耗哲学家"),
        .init(id: "meeting", resource: "MeetingEmail", title: "本来可以是封邮件", subtitle: "会议生存指南"),
        .init(id: "away", resource: "AwayWorking", title: "人在休息，活在运行", subtitle: "赛博同事在线"),
        .init(id: "elsewhere", resource: "QuietOffice", title: "正在装作不在工位", subtitle: "安静离席中"),
        .init(id: "inbox", resource: "InboxReply", title: "已读，乱回", subtitle: "收件箱求生指南"),
        .init(id: "fish", resource: "FishMode", title: "正在认真摸鱼", subtitle: "深度摸鱼模式"),
        .init(id: "loading", resource: "LoadingDog", title: "精神状态：加载中", subtitle: "请耐心等待 99%"),
        .init(id: "pie", resource: "PieReserve", title: "老板画的饼，先放冰箱", subtitle: "战略储备，慢慢消化")
    ]
    static func find(_ id: String?) -> BuiltInWallpaper? { all.first { $0.id == id } }
}

private final class FlippedView: NSView { override var isFlipped: Bool { true } }
private final class ArtworkView: NSImageView {
    override var intrinsicContentSize: NSSize { NSSize(width: NSView.noIntrinsicMetric, height: NSView.noIntrinsicMetric) }
    init(height: CGFloat, radius: CGFloat) {
        super.init(frame: .zero)
        imageScaling = .scaleProportionallyUpOrDown
        wantsLayer = true
        layer?.cornerRadius = radius
        layer?.masksToBounds = true
        layer?.backgroundColor = NSColor(calibratedRed: 0.96, green: 0.94, blue: 0.90, alpha: 1).cgColor
        heightAnchor.constraint(equalToConstant: height).isActive = true
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
}

final class PreferencesWindow: NSWindowController {
    private let tabs = NSTabView()
    private let preview = ArtworkView(height: 288, radius: 14)
    private let artworkTitle = NSTextField(labelWithString: "")
    private let artworkSubtitle = NSTextField(labelWithString: "")
    private let awake = NSButton(checkboxWithTitle: "防窥时保持电脑和显示器唤醒", target: nil, action: nil)
    private var navigationButtons: [NSButton] = []
    private var wallpaperButtons: [String: NSButton] = [:]
    private var selectedID: String?
    var chooseWallpaper: (() -> Void)?
    var resetWallpaper: (() -> Void)?
    var chooseBuiltIn: ((String) -> Void)?
    var changeKeepAwake: ((Bool) -> Void)?
    var enableProtection: (() -> Void)?

    init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 940, height: 660),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "在场 · StillHere"
        window.isReleasedWhenClosed = false
        window.contentMinSize = NSSize(width: 760, height: 550)
        window.titlebarAppearsTransparent = true
        super.init(window: window)

        let sidebar = NSVisualEffectView()
        sidebar.material = .sidebar
        sidebar.blendingMode = .withinWindow
        sidebar.state = .active
        sidebar.translatesAutoresizingMaskIntoConstraints = false
        window.contentView!.addSubview(sidebar)
        let mark = NSImageView(image: NSImage(systemSymbolName: "eye.slash.fill", accessibilityDescription: "在场") ?? NSImage())
        mark.contentTintColor = .controlAccentColor
        mark.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 21, weight: .semibold)
        mark.widthAnchor.constraint(equalToConstant: 30).isActive = true
        let name = label("在场", size: 22, weight: .bold)
        let brand = row([mark, name], spacing: 10)
        let brandSubtitle = secondary("STILLHERE", size: 10)
        brandSubtitle.font = .monospacedSystemFont(ofSize: 10, weight: .medium)
        let nav = NSStackView()
        nav.orientation = .vertical
        nav.alignment = .leading
        nav.spacing = 5
        for (i, item) in [("概览", "rectangle.inset.filled"), ("壁纸库", "photo.on.rectangle.angled"), ("偏好设置", "slider.horizontal.3")].enumerated() {
            let button = NSButton(title: item.0, target: self, action: #selector(navigate(_:)))
            button.image = NSImage(systemSymbolName: item.1, accessibilityDescription: nil)
            button.imagePosition = .imageLeading
            button.bezelStyle = .rounded
            button.isBordered = false
            button.setButtonType(.toggle)
            button.alignment = .left
            button.controlSize = .large
            button.tag = i
            button.setAccessibilityLabel(item.0)
            button.widthAnchor.constraint(equalToConstant: 158).isActive = true
            navigationButtons.append(button)
            nav.addArrangedSubview(button)
        }
        let sideNote = secondary("人可以离席\n工作继续在场", size: 12)
        sideNote.maximumNumberOfLines = 2
        let side = column([brand, brandSubtitle, nav], spacing: 8)
        side.setCustomSpacing(30, after: brandSubtitle)
        side.translatesAutoresizingMaskIntoConstraints = false
        sideNote.translatesAutoresizingMaskIntoConstraints = false
        sidebar.addSubview(side); sidebar.addSubview(sideNote)
        NSLayoutConstraint.activate([
            sidebar.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor),
            sidebar.topAnchor.constraint(equalTo: window.contentView!.topAnchor),
            sidebar.bottomAnchor.constraint(equalTo: window.contentView!.bottomAnchor),
            sidebar.widthAnchor.constraint(equalToConstant: 190),
            side.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor, constant: 18),
            side.trailingAnchor.constraint(equalTo: sidebar.trailingAnchor, constant: -14),
            side.topAnchor.constraint(equalTo: sidebar.topAnchor, constant: 39),
            sideNote.leadingAnchor.constraint(equalTo: side.leadingAnchor),
            sideNote.bottomAnchor.constraint(equalTo: sidebar.bottomAnchor, constant: -26)
        ])
        tabs.tabViewType = .noTabsNoBorder
        tabs.translatesAutoresizingMaskIntoConstraints = false
        window.contentView!.addSubview(tabs)
        NSLayoutConstraint.activate([
            tabs.leadingAnchor.constraint(equalTo: sidebar.trailingAnchor),
            tabs.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor),
            tabs.topAnchor.constraint(equalTo: window.contentView!.topAnchor),
            tabs.bottomAnchor.constraint(equalTo: window.contentView!.bottomAnchor)
        ])
        addTab(makeOverview(), id: "overview")
        addTab(makeLibrary(), id: "library")
        addTab(makeSettings(), id: "settings")
        selectPage(0)
        window.center()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    private func makeOverview() -> NSView {
        let eyebrow = secondary("YOUR SPACE, YOUR RULES", size: 10)
        eyebrow.font = .monospacedSystemFont(ofSize: 10, weight: .semibold)
        let title = label("离席，工作继续。", size: 28, weight: .bold)
        let description = secondary("让屏幕安静下来，桌面里的工作照常进行。", size: 13)
        let stateIcon = NSImageView(image: NSImage(systemSymbolName: "circle.fill", accessibilityDescription: nil) ?? NSImage())
        stateIcon.contentTintColor = .systemGreen
        stateIcon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 7, weight: .regular)
        let state = secondary("桌面正常显示", size: 12)
        let status = row([stateIcon, state], spacing: 6)
        let header = row([column([eyebrow, title, description], spacing: 5), flexible(), status], spacing: 10)
        preview.setAccessibilityLabel("当前隐私壁纸预览")
        artworkTitle.font = .systemFont(ofSize: 15, weight: .semibold)
        artworkSubtitle.font = .systemFont(ofSize: 12)
        artworkSubtitle.textColor = .secondaryLabelColor
        let choose = NSButton(title: "更换壁纸", target: self, action: #selector(openLibrary))
        choose.bezelStyle = .rounded
        let artworkInfo = row([column([artworkTitle, artworkSubtitle], spacing: 4), flexible(), choose], spacing: 10)
        let enable = NSButton(title: "开启防窥", target: self, action: #selector(enableClicked))
        enable.bezelStyle = .rounded
        enable.controlSize = .large
        enable.bezelColor = .controlAccentColor
        enable.contentTintColor = .white
        enable.keyEquivalent = ""
        let shortcut = secondary("⌃ ⌥ ⌘ P   开启 / 退出防窥", size: 12)
        let action = row([enable, shortcut], spacing: 14)
        let page = column([header, preview, artworkInfo, action], spacing: 18)
        for v in [header, preview, artworkInfo, action] { v.widthAnchor.constraint(equalTo: page.widthAnchor).isActive = true }
        return scrollPage(page)
    }

    private func makeLibrary() -> NSView {
        let title = label("壁纸库", size: 27, weight: .bold)
        let description = secondary("选一张陪你离席。你的桌面工作会继续。", size: 13)
        var rows: [NSView] = []
        for pair in stride(from: 0, to: BuiltInWallpaper.all.count, by: 2) {
            let a = wallpaperCard(BuiltInWallpaper.all[pair])
            let b: NSView = pair + 1 < BuiltInWallpaper.all.count
                ? wallpaperCard(BuiltInWallpaper.all[pair + 1]) : NSView()
            let line = row([a, b], spacing: 14)
            line.distribution = .fillEqually
            rows.append(line)
        }
        let choose = NSButton(title: "选择自己的图片…", target: self, action: #selector(choose))
        choose.bezelStyle = .rounded
        let chooseDetail = secondary("支持 PNG、JPEG、HEIC 和 GIF。", size: 12)
        let buttons = row([choose, chooseDetail], spacing: 10)
        let page = column([title, description] + rows + [buttons], spacing: 14)
        for v in rows + [buttons] { v.widthAnchor.constraint(equalTo: page.widthAnchor).isActive = true }
        return scrollPage(page)
    }

    private func wallpaperCard(_ item: BuiltInWallpaper) -> NSView {
        let art = ArtworkView(height: 150, radius: 10)
        art.image = item.image
        art.setAccessibilityLabel(item.title + " 壁纸预览")
        let title = label(item.title, size: 13, weight: .semibold)
        let sub = secondary(item.subtitle, size: 11)
        let button = NSButton(title: "使用壁纸", target: self, action: #selector(builtInClicked(_:)))
        button.identifier = NSUserInterfaceItemIdentifier(item.id)
        button.bezelStyle = .rounded
        button.setAccessibilityLabel("使用壁纸：" + item.title)
        wallpaperButtons[item.id] = button
        let card = column([art, title, sub, button], spacing: 6)
        art.widthAnchor.constraint(equalTo: card.widthAnchor).isActive = true
        return card
    }

    private func makeSettings() -> NSView {
        let title = label("偏好设置", size: 27, weight: .bold)
        let intro = secondary("让在场按你习惯的方式工作。", size: 13)
        awake.target = self; awake.action = #selector(awakeChanged)
        let awakeDetail = secondary("适合离席时继续运行自动化。系统锁屏和合盖仍由 macOS 控制。", size: 12)
        let awakeSection = column([label("屏幕与唤醒", size: 16, weight: .semibold), awake, awakeDetail], spacing: 10)
        let shortcutSection = column([label("快捷键", size: 16, weight: .semibold), secondary("⌃ Control   ⌥ Option   ⌘ Command   P", size: 13), secondary("按一次开启，再按一次退出防窥。知道快捷键的人也可以退出。", size: 12)], spacing: 8)
        let page = column([title, intro, separator(), awakeSection, separator(), shortcutSection], spacing: 16)
        for v in [awakeSection, shortcutSection] { v.widthAnchor.constraint(equalTo: page.widthAnchor).isActive = true }
        for v in page.arrangedSubviews where v is NSBox { v.widthAnchor.constraint(equalTo: page.widthAnchor).isActive = true }
        return scrollPage(page)
    }

    private func addTab(_ view: NSView, id: String) { let item = NSTabViewItem(identifier: id); item.view = view; tabs.addTabViewItem(item) }
    private func selectPage(_ index: Int) {
        tabs.selectTabViewItem(at: index)
        for (i, button) in navigationButtons.enumerated() { button.state = i == index ? .on : .off }
    }
    @objc private func navigate(_ sender: NSButton) { selectPage(sender.tag) }
    @objc private func openLibrary() { selectPage(1) }
    @objc private func enableClicked() { enableProtection?() }
    @objc private func choose() { chooseWallpaper?() }
    @objc private func builtInClicked(_ sender: NSButton) { if let id = sender.identifier?.rawValue { chooseBuiltIn?(id) } }
    @objc private func awakeChanged() { changeKeepAwake?(awake.state == .on) }
    func present(image: NSImage, keepAwake: Bool, selectedID: String?) {
        updateImage(image, selectedID: selectedID)
        awake.state = keepAwake ? .on : .off
        selectPage(0)
        showWindow(nil); NSApp.activate(ignoringOtherApps: true); window?.makeKeyAndOrderFront(nil)
    }
    func updateImage(_ image: NSImage, selectedID: String?) {
        self.selectedID = selectedID
        preview.image = image
        let item = BuiltInWallpaper.find(selectedID)
        artworkTitle.stringValue = item?.title ?? "自选壁纸"
        artworkSubtitle.stringValue = item?.subtitle ?? "你的个人壁纸"
        for (id, button) in wallpaperButtons { button.title = id == selectedID ? "当前使用" : "使用壁纸"; button.isEnabled = id != selectedID }
    }
}

private func label(_ value: String, size: CGFloat, weight: NSFont.Weight) -> NSTextField {
    let result = NSTextField(labelWithString: value); result.font = .systemFont(ofSize: size, weight: weight); return result
}
private func secondary(_ value: String, size: CGFloat) -> NSTextField {
    let result = NSTextField(wrappingLabelWithString: value); result.font = .systemFont(ofSize: size); result.textColor = .secondaryLabelColor; return result
}
private func column(_ views: [NSView], spacing: CGFloat) -> NSStackView {
    let result = NSStackView(views: views); result.orientation = .vertical; result.alignment = .leading; result.spacing = spacing; return result
}
private func row(_ views: [NSView], spacing: CGFloat) -> NSStackView {
    let result = NSStackView(views: views); result.orientation = .horizontal; result.alignment = .centerY; result.spacing = spacing; return result
}
private func flexible() -> NSView { let view = NSView(); view.setContentHuggingPriority(.defaultLow, for: .horizontal); return view }
private func separator() -> NSBox { let box = NSBox(); box.boxType = .separator; return box }
private func scrollPage(_ page: NSStackView) -> NSScrollView {
    let scroll = NSScrollView(); scroll.hasVerticalScroller = true; scroll.autohidesScrollers = true; scroll.drawsBackground = false
    let document = FlippedView(); document.translatesAutoresizingMaskIntoConstraints = false; scroll.documentView = document
    page.translatesAutoresizingMaskIntoConstraints = false; document.addSubview(page)
    NSLayoutConstraint.activate([
        document.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor),
        page.leadingAnchor.constraint(equalTo: document.leadingAnchor, constant: 36),
        page.trailingAnchor.constraint(equalTo: document.trailingAnchor, constant: -36),
        page.topAnchor.constraint(equalTo: document.topAnchor, constant: 32),
        page.bottomAnchor.constraint(equalTo: document.bottomAnchor, constant: -32)
    ])
    return scroll
}
