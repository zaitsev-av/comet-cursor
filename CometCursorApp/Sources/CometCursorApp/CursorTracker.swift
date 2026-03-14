import AppKit
import CoreGraphics

// Используем глобальную C-функцию, т.к. CGEventTapCallBack — C-указатель на функцию.
private func eventTapCallback(
    _ proxy: CGEventTapProxy,
    _ type: CGEventType,
    _ event: CGEvent,
    _ userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    // macOS автоматически отключает tap при перегрузке или смене политик безопасности.
    // Переподключаемся немедленно, иначе события мыши перестают приходить навсегда.
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
#if DEBUG
        print("[TAP] tap disabled (type=\(type.rawValue)), re-enabling")
#endif
        if let ptr = userInfo {
            let tracker = Unmanaged<CursorTracker>.fromOpaque(ptr).takeUnretainedValue()
            if let tap = tracker.eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
        }
        return nil
    }

    // CGEventTap callback не должен retain'ить входящий event при возврате:
    // event принадлежит системе и должен возвращаться как unretained.
    guard let ptr = userInfo else { return Unmanaged.passUnretained(event) }
    let tracker = Unmanaged<CursorTracker>.fromOpaque(ptr).takeUnretainedValue()
    let loc = event.location
    DispatchQueue.main.async { tracker.handleMoveEventTap(loc) }
    return Unmanaged.passUnretained(event)
}

final class CursorTracker {
    static let shared = CursorTracker()

    /// Вызывается на главном потоке при каждом движении мыши.
    var onMove: ((CGFloat, CGFloat) -> Void)?

    fileprivate var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var pollTimer: Timer?
    private var lastDeliveredLocation: CGPoint?
    private var lastEventTapMoveTime: TimeInterval = 0
    private lazy var selfPtr: UnsafeMutableRawPointer = Unmanaged.passUnretained(self).toOpaque()

    var isTrusted: Bool { AXIsProcessTrusted() }
    var isUsingEventTap: Bool { eventTap != nil }

    func start(showPromptIfDenied: Bool = false) {
        startPollingCursor()
        ensureEventTap(showPromptIfDenied: showPromptIfDenied)
    }

    func ensureEventTap(showPromptIfDenied: Bool = false) {
        guard isTrusted else {
            tearDownEventTap()
            if showPromptIfDenied { showAccessibilityError() }
            return
        }

        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: true)
            return
        }

        createEventTap()
    }

    func stop() {
        pollTimer?.invalidate()
        pollTimer = nil
        tearDownEventTap()
        lastDeliveredLocation = nil
        lastEventTapMoveTime = 0
    }

    private func createEventTap() {
        let mask = CGEventMask(
            (1 << CGEventType.mouseMoved.rawValue) |
            (1 << CGEventType.leftMouseDragged.rawValue) |
            (1 << CGEventType.rightMouseDragged.rawValue)
        )

        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: eventTapCallback,
            userInfo: selfPtr
        ) else {
            if !isTrusted {
                showAccessibilityError()
            }
            // Не прекращаем трекинг: polling курсора продолжит работу даже без tap.
            return
        }

#if DEBUG
        print("[TRACKER] Event tap created successfully")
#endif
        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    fileprivate func handleMoveEventTap(_ loc: CGPoint) {
        lastEventTapMoveTime = ProcessInfo.processInfo.systemUptime
        deliverMove(loc)
    }

    private func startPollingCursor() {
        guard pollTimer == nil else { return }
        // Поллинг делает трекинг независимым от фокуса приложения и состояний event tap.
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 120.0, repeats: true) { [weak self] _ in
            guard let self else { return }

            let now = ProcessInfo.processInfo.systemUptime
            // Если tap недавно присылал события, берём его как основной источник.
            if now - self.lastEventTapMoveTime < 0.2 { return }

            guard let loc = CGEvent(source: nil)?.location else { return }
            self.deliverMove(loc)
        }
    }

    private func deliverMove(_ loc: CGPoint) {
        if let last = lastDeliveredLocation {
            let dx = loc.x - last.x
            let dy = loc.y - last.y
            if (dx * dx + dy * dy) < 0.25 { return }
        }
        lastDeliveredLocation = loc
        onMove?(loc.x, loc.y)
    }

    private func tearDownEventTap() {
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
            self.runLoopSource = nil
        }

        if let eventTap {
            CFMachPortInvalidate(eventTap)
            self.eventTap = nil
        }
    }

    private func showAccessibilityError() {
        let l = L10n(lang: AppLanguage(rawValue: UserDefaults.standard.string(forKey: "language") ?? "en") ?? .en)
        let alert = NSAlert()
        alert.messageText     = l.accessibilityAlertTitle
        alert.informativeText = l.accessibilityAlertBody
        alert.alertStyle      = .warning
        alert.addButton(withTitle: l.accessibilityAlertOpen)
        alert.addButton(withTitle: l.accessibilityAlertCancel)
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(
                URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
            )
        }
    }
}
