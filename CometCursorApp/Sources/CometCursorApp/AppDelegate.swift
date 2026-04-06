import AppKit
import Combine
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {

    let settings = SettingsModel()
    private let trailManager = TrailManager()

    private var statusItem: NSStatusItem!
    private var renderers: [CometRenderer] = []
    private var settingsWindow: NSWindow?
    private var onboardingWindow: NSWindow?
    private var toggleMenuItem: NSMenuItem?
    private var settingsMenuItem: NSMenuItem?
    private var supportMenuItem: NSMenuItem?
    private var quitMenuItem: NSMenuItem?
    private var workspaceObserverTokens: [NSObjectProtocol] = []
    private var appObserverTokens: [NSObjectProtocol] = []
    private var zOrderEnforcerTimer: Timer?
    private var languageCancellable: AnyCancellable?
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

        let toggle = NSMenuItem(title: l.menuEnabled, action: #selector(toggleEnabled), keyEquivalent: "")
        toggle.state = settings.isEnabled ? .on : .off
        menu.addItem(toggle)
        toggleMenuItem = toggle

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
        toggleMenuItem?.state = settings.isEnabled ? .on : .off
        syncOverlayVisibility()
    }

    @objc private func openBoosty() {
        NSWorkspace.shared.open(URL(string: "https://boosty.to/zaitsev_av")!)
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let view = SettingsView(settings: settings)
            let controller = NSHostingController(rootView: view)
            controller.view.frame = CGRect(x: 0, y: 0, width: 460, height: 620)
            let win = NSWindow(contentViewController: controller)
            win.title = settings.l10n.windowTitle
            win.styleMask = [.titled, .closable]
            win.isReleasedWhenClosed = false
            win.setContentSize(CGSize(width: 460, height: 620))
            win.center()
            settingsWindow = win
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func updateMenuTitles() {
        let l = settings.l10n
        toggleMenuItem?.title   = l.menuEnabled
        settingsMenuItem?.title = l.menuSettings
        supportMenuItem?.title  = l.menuSupport
        quitMenuItem?.title     = l.menuQuit
        settingsWindow?.title   = l.windowTitle
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
