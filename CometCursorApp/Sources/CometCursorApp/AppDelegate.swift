import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {

    let settings = SettingsModel()
    private let trailManager = TrailManager()

    private var statusItem: NSStatusItem!
    private var renderers: [CometRenderer] = []
    private var settingsWindow: NSWindow?
    private var toggleMenuItem: NSMenuItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupStatusBar()
        setupRenderers()
        startTracking()
    }

    // MARK: - Status bar

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let btn = statusItem.button {
            btn.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: "Comet Cursor")
        }

        let menu = NSMenu()

        let toggle = NSMenuItem(title: "Включён", action: #selector(toggleEnabled), keyEquivalent: "")
        toggle.state = settings.isEnabled ? .on : .off
        menu.addItem(toggle)
        toggleMenuItem = toggle

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Настройки…", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Выйти", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem.menu = menu
    }

    @objc private func toggleEnabled() {
        settings.isEnabled.toggle()
        toggleMenuItem?.state = settings.isEnabled ? .on : .off
        if !settings.isEnabled { trailManager.clear() }
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let controller = NSHostingController(rootView: SettingsView(settings: settings))
            let win = NSWindow(contentViewController: controller)
            win.title = "Comet Cursor — Настройки"
            win.styleMask = [.titled, .closable]
            win.isReleasedWhenClosed = false
            win.center()
            settingsWindow = win
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Renderers

    private func setupRenderers() {
        for (i, screen) in NSScreen.screens.enumerated() {
            let renderer = CometRenderer(
                screen: screen,
                trailManager: trailManager,
                settings: settings,
                isPrimary: i == 0
            )
            renderers.append(renderer)
        }
    }

    // MARK: - Cursor tracking

    private func startTracking() {
        CursorTracker.shared.onMove = { [weak self] x, y in
            guard let self, self.settings.isEnabled else { return }
            self.trailManager.update(
                x: Float(x), y: Float(y),
                maxLength: Int(self.settings.trailLength)
            )
        }
        CursorTracker.shared.start()
    }
}
