import AppKit
import Combine
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {

    let settings = SettingsModel()
    private let trailManager = TrailManager()

    private var statusItem: NSStatusItem!
    private var renderers: [CometRenderer] = []
    private var settingsWindow: NSWindow?
    private var settingsHostingController: NSHostingController<SettingsView>?
    private var onboardingWindow: NSWindow?
    private var menuHeaderSwitch: MenuHeaderSwitchButton?
    private weak var menuHeaderTitleField: NSTextField?
    private var settingsMenuItem: NSMenuItem?
    private var supportMenuItem: NSMenuItem?
    private var quitMenuItem: NSMenuItem?
    private var workspaceObserverTokens: [NSObjectProtocol] = []
    private var appObserverTokens: [NSObjectProtocol] = []
    private var zOrderEnforcerTimer: Timer?
    private var languageCancellable: AnyCancellable?
    private var enabledCancellable: AnyCancellable?
    private var exclusionCancellable: AnyCancellable?
    private var shortcutCancellable: AnyCancellable?
    private var launchAtLoginCancellable: AnyCancellable?
    private var hasStartedApp = false
    private var permissionMonitorTimer: Timer?

    // Предотвращаем App Nap - macOS иначе останавливает render loop когда приложение неактивно
    private var renderActivity: NSObjectProtocol?

    deinit {
        zOrderEnforcerTimer?.invalidate()
        zOrderEnforcerTimer = nil
        permissionMonitorTimer?.invalidate()
        permissionMonitorTimer = nil
        removeObservers()
        if let renderActivity {
            ProcessInfo.processInfo.endActivity(renderActivity)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        renderActivity = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiated, .latencyCritical],
            reason: "Cursor trail rendering"
        )
        NSApp.setActivationPolicy(.accessory)
        setupStatusBar()
        enabledCancellable = settings.$isEnabled
            .receive(on: DispatchQueue.main)
            .sink { [weak self] enabled in
                guard let self, let sw = self.menuHeaderSwitch else { return }
                if sw.isOn != enabled {
                    sw.isOn = enabled
                }
            }
        languageCancellable = settings.$language
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.updateMenuTitles()
                self.settings.updateLaunchAtLoginStatus(
                    LaunchAtLoginManager.shared.currentStatusMessage(language: self.settings.language)
                )
            }

        exclusionCancellable = settings.$excludedApps
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.syncOverlayVisibility() }

        shortcutCancellable = settings.$globalShortcutEnabled
            .receive(on: DispatchQueue.main)
            .sink { HotkeyManager.shared.setEnabled($0) }

        launchAtLoginCancellable = settings.$launchAtLogin
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] enabled in
                guard let self else { return }
                let status = LaunchAtLoginManager.shared.applyPreference(enabled, language: self.settings.language)
                self.settings.updateLaunchAtLoginStatus(status)
            }

        if settings.launchAtLogin {
            settings.updateLaunchAtLoginStatus(
                LaunchAtLoginManager.shared.applyPreference(true, language: settings.language)
            )
        } else {
            settings.updateLaunchAtLoginStatus(
                LaunchAtLoginManager.shared.currentStatusMessage(language: settings.language)
            )
        }

        if AXIsProcessTrusted() {
            startApp()
        } else {
            showOnboarding()
        }
    }

    // MARK: - Onboarding

    private func showOnboarding() {
        guard !AXIsProcessTrusted() else {
            onboardingWindow?.close()
            onboardingWindow = nil
            startApp()
            return
        }

        if let onboardingWindow {
            onboardingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let view = OnboardingView(settings: settings) { [weak self] in
            self?.onboardingWindow?.close()
            self?.onboardingWindow = nil
            self?.startApp()
        }
        let controller = NSHostingController(rootView: view)
        let win = NSWindow(contentViewController: controller)
        win.styleMask = [.titled, .closable, .fullSizeContentView]
        win.titlebarAppearsTransparent = true
        win.titleVisibility = .hidden
        win.isReleasedWhenClosed = false
        win.center()
        onboardingWindow = win
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func startApp() {
        guard !hasStartedApp else {
            refreshActiveApplication()
            syncOverlayVisibility()
            return
        }
        hasStartedApp = true
        rebuildRenderers()
        startZOrderEnforcer()
        configureTrackingCallbacks()
        ensureTracking()
        startPermissionMonitor()
        startShortcut()
        subscribeToWorkspaceEvents()
        refreshActiveApplication()
        syncOverlayVisibility()
    }

    // MARK: - Status bar

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let btn = statusItem.button {
            btn.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: "Comet Cursor")
        }

        let menu = NSMenu()
        menu.delegate = self

        let l = settings.l10n

        let headerItem = NSMenuItem()
        headerItem.view = makeStatusBarMenuHeaderView(brandTitle: l.settingsHeaderTitle)
        menu.addItem(headerItem)

        menu.addItem(.separator())
        let settingsItem = NSMenuItem(title: l.menuSettings, action: #selector(openSettings), keyEquivalent: ",")
        menu.addItem(settingsItem)
        settingsMenuItem = settingsItem
        menu.addItem(.separator())
        let supportItem = NSMenuItem(title: l.menuSupport, action: #selector(openBoosty), keyEquivalent: "")
        menu.addItem(supportItem)
        supportMenuItem = supportItem
        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: l.menuQuit, action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)
        quitMenuItem = quitItem

        statusItem.menu = menu
    }

    @objc private func toggleEnabled() {
        settings.isEnabled.toggle()
        menuHeaderSwitch?.isOn = settings.isEnabled
        syncOverlayVisibility()
    }

    @objc private func menuHeaderSwitchChanged(_ sender: MenuHeaderSwitchButton) {
        settings.isEnabled = sender.isOn
        syncOverlayVisibility()
    }

    @objc private func openBoosty() {
        NSWorkspace.shared.open(URL(string: "https://boosty.to/zaitsev_av")!)
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let view = SettingsView(settings: settings)
            let controller = NSHostingController(rootView: view)
            controller.view.translatesAutoresizingMaskIntoConstraints = false

            let effectView = NSVisualEffectView()
            effectView.material = .sidebar
            effectView.blendingMode = .behindWindow
            effectView.state = .active
            effectView.autoresizingMask = [.width, .height]
            effectView.addSubview(controller.view)
            NSLayoutConstraint.activate([
                controller.view.leadingAnchor.constraint(equalTo: effectView.leadingAnchor),
                controller.view.trailingAnchor.constraint(equalTo: effectView.trailingAnchor),
                controller.view.topAnchor.constraint(equalTo: effectView.topAnchor),
                controller.view.bottomAnchor.constraint(equalTo: effectView.bottomAnchor),
            ])

            let size = CGSize(width: 460, height: 620)
            let win = NSWindow(
                contentRect: NSRect(origin: .zero, size: size),
                styleMask: [.titled, .closable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            win.contentView = effectView
            win.title = settings.l10n.windowTitle
            win.titlebarAppearsTransparent = true
            win.titleVisibility = .hidden
            win.isOpaque = false
            win.backgroundColor = .clear
            win.isReleasedWhenClosed = false
            win.setContentSize(size)
            win.center()
            settingsHostingController = controller
            settingsWindow = win
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func updateMenuTitles() {
        let l = settings.l10n
        settingsMenuItem?.title = l.menuSettings
        supportMenuItem?.title  = l.menuSupport
        quitMenuItem?.title     = l.menuQuit
        settingsWindow?.title   = l.windowTitle
        menuHeaderTitleField?.stringValue = l.settingsHeaderTitle
    }

    private func makeStatusBarMenuHeaderView(brandTitle: String) -> NSView {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 260, height: 44))
        let icon = NSImageView()
        if let img = NSImage(systemSymbolName: "sparkles", accessibilityDescription: "Comet Cursor") {
            icon.image = img
            icon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        }
        icon.translatesAutoresizingMaskIntoConstraints = false

        let title = NSTextField(labelWithString: brandTitle)
        title.font = .systemFont(ofSize: 13, weight: .semibold)
        title.translatesAutoresizingMaskIntoConstraints = false

        let sw = MenuHeaderSwitchButton()
        sw.translatesAutoresizingMaskIntoConstraints = false
        sw.isOn = settings.isEnabled
        sw.target = self
        sw.action = #selector(menuHeaderSwitchChanged(_:))

        container.addSubview(icon)
        container.addSubview(title)
        container.addSubview(sw)

        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            icon.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 20),
            icon.heightAnchor.constraint(equalToConstant: 20),
            title.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 8),
            title.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            sw.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            sw.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            sw.widthAnchor.constraint(equalToConstant: 38),
            sw.heightAnchor.constraint(equalToConstant: 22),
            title.trailingAnchor.constraint(lessThanOrEqualTo: sw.leadingAnchor, constant: -8),
        ])

        menuHeaderSwitch = sw
        menuHeaderTitleField = title
        return container
    }

    // MARK: - Renderers

    private func rebuildRenderers() {
        renderers.forEach { $0.shutdown() }
        renderers.removeAll()

        for screen in NSScreen.screens {
            let isPrimaryScreen = screen.frame.minX == 0 && screen.frame.minY == 0
            let renderer = CometRenderer(
                screen: screen,
                trailManager: trailManager,
                settings: settings,
                isPrimary: isPrimaryScreen
            )
            renderers.append(renderer)
        }
    }

    // MARK: - Window ordering

    /// Панели-оверлеи уходят за другие окна при каждой смене активного приложения.
    /// Подписываемся на workspace-события и восстанавливаем z-order.
    private func subscribeToWorkspaceEvents() {
        removeObservers()

        let nc = NSWorkspace.shared.notificationCenter
        let didActivateToken = nc.addObserver(forName: NSWorkspace.didActivateApplicationNotification,
                                              object: nil, queue: .main) { [weak self] _ in
            self?.refreshActiveApplication()
            self?.renderers.forEach { $0.orderFront() }
        }
        workspaceObserverTokens.append(didActivateToken)

        let activeSpaceToken = nc.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification,
                                              object: nil, queue: .main) { [weak self] _ in
            self?.refreshActiveApplication()
            self?.renderers.forEach { $0.orderFront() }
        }
        workspaceObserverTokens.append(activeSpaceToken)

        let anc = NotificationCenter.default
        let didBecomeActiveToken = anc.addObserver(forName: NSApplication.didBecomeActiveNotification,
                                                   object: nil, queue: .main) { [weak self] _ in
            self?.ensureTracking()
            self?.renderers.forEach { $0.orderFront() }
        }
        appObserverTokens.append(didBecomeActiveToken)

        let didResignActiveToken = anc.addObserver(forName: NSApplication.didResignActiveNotification,
                                                   object: nil, queue: .main) { [weak self] _ in
            self?.renderers.forEach { $0.orderFront() }
        }
        appObserverTokens.append(didResignActiveToken)

        let didChangeScreenToken = anc.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                                   object: nil, queue: .main) { [weak self] _ in
            self?.rebuildRenderers()
        }
        appObserverTokens.append(didChangeScreenToken)

        // Первый показ — ждём следующего цикла run loop после полного запуска
        DispatchQueue.main.async { self.renderers.forEach { $0.orderFront() } }
    }

    private func startZOrderEnforcer() {
        zOrderEnforcerTimer?.invalidate()
        // Фолбэк: некоторые окна остаются "visible", но уходят под активное приложение.
        // Периодический orderFrontRegardless стабилизирует overlay при запуске из Finder.
        zOrderEnforcerTimer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: true) { [weak self] _ in
            guard let self, self.canRenderTrail else { return }
            self.renderers.forEach { $0.orderFront() }
        }
    }

    private func removeObservers() {
        let workspaceNC = NSWorkspace.shared.notificationCenter
        for token in workspaceObserverTokens {
            workspaceNC.removeObserver(token)
        }
        workspaceObserverTokens.removeAll()

        let appNC = NotificationCenter.default
        for token in appObserverTokens {
            appNC.removeObserver(token)
        }
        appObserverTokens.removeAll()
    }

    // MARK: - Cursor tracking

    private func configureTrackingCallbacks() {
        CursorTracker.shared.onMove = { [weak self] x, y in
            guard let self, self.canRenderTrail else { return }
            self.trailManager.update(
                x: Float(x), y: Float(y),
                maxLength: Int(self.settings.trailLength)
            )
        }
    }

    private func ensureTracking(showPromptIfDenied: Bool = false) {
        CursorTracker.shared.start(showPromptIfDenied: showPromptIfDenied)
    }

    private func startPermissionMonitor() {
        permissionMonitorTimer?.invalidate()
        permissionMonitorTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.ensureTracking()
        }
    }

    private func startShortcut() {
        HotkeyManager.shared.onToggle = { [weak self] in
            self?.toggleEnabled()
        }
        HotkeyManager.shared.setEnabled(settings.globalShortcutEnabled)
    }

    private var canRenderTrail: Bool {
        settings.isEnabled && !settings.isExcluded(bundleID: settings.activeAppBundleID)
    }

    private func refreshActiveApplication() {
        ensureTracking()
        let app = NSWorkspace.shared.frontmostApplication
        settings.setActiveApplication(
            name: app?.localizedName ?? "",
            bundleID: app?.bundleIdentifier ?? ""
        )
        syncOverlayVisibility()
    }

    private func syncOverlayVisibility() {
        let shouldShowOverlay = canRenderTrail
        if !shouldShowOverlay {
            trailManager.clear()
        }
        renderers.forEach { $0.setVisible(shouldShowOverlay) }
        if shouldShowOverlay {
            renderers.forEach { $0.orderFront() }
        }
    }
}

// MARK: - NSMenuDelegate

extension AppDelegate: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        renderers.forEach { $0.orderFront() }
    }

    func menuDidClose(_ menu: NSMenu) {
        // После закрытия меню система может переупорядочить окна — восстанавливаем z-order.
        DispatchQueue.main.async {
            self.renderers.forEach { $0.orderFront() }
        }
    }
}

private final class MenuHeaderSwitchButton: NSButton {
    var isOn = false {
        didSet { updateAppearance() }
    }

    private let knobLayer = CALayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    override func layout() {
        super.layout()
        updateAppearance()
    }

    override func mouseDown(with event: NSEvent) {
        isOn.toggle()
        if let action {
            NSApp.sendAction(action, to: target, from: self)
        }
    }

    private func commonInit() {
        title = ""
        isBordered = false
        wantsLayer = true
        layer?.masksToBounds = false
        knobLayer.backgroundColor = NSColor.white.cgColor
        knobLayer.shadowColor = NSColor.black.cgColor
        knobLayer.shadowOpacity = 0.18
        knobLayer.shadowRadius = 2
        knobLayer.shadowOffset = CGSize(width: 0, height: 1)
        layer?.addSublayer(knobLayer)
        setAccessibilityRole(.button)
        updateAppearance()
    }

    private func updateAppearance() {
        guard let layer else { return }
        let bounds = self.bounds
        let knobDiameter: CGFloat = max(bounds.height - 6, 1)
        let x = isOn ? bounds.width - knobDiameter - 3 : 3

        layer.cornerRadius = bounds.height / 2
        layer.backgroundColor = (isOn ? NSColor.systemBlue : NSColor.tertiaryLabelColor).cgColor
        knobLayer.cornerRadius = knobDiameter / 2
        knobLayer.frame = CGRect(x: x, y: 3, width: knobDiameter, height: knobDiameter)
        setAccessibilityValue(isOn ? "On" : "Off")
    }
}
