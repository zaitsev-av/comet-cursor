import AppKit
import CoreGraphics

// Используем глобальную C-функцию, т.к. CGEventTapCallBack — C-указатель на функцию.
private func eventTapCallback(
    _ proxy: CGEventTapProxy,
    _ type: CGEventType,
    _ event: CGEvent,
    _ userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let ptr = userInfo else { return Unmanaged.passRetained(event) }
    let tracker = Unmanaged<CursorTracker>.fromOpaque(ptr).takeUnretainedValue()
    let loc = event.location
    DispatchQueue.main.async { tracker.onMove?(loc.x, loc.y) }
    return Unmanaged.passRetained(event)
}

final class CursorTracker {
    static let shared = CursorTracker()

    /// Вызывается на главном потоке при каждом движении мыши.
    var onMove: ((CGFloat, CGFloat) -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    func start() {
        let mask = CGEventMask(
            (1 << CGEventType.mouseMoved.rawValue) |
            (1 << CGEventType.leftMouseDragged.rawValue) |
            (1 << CGEventType.rightMouseDragged.rawValue)
        )

        // selfPtr живёт на протяжении всего срока жизни синглтона — утечка допустима.
        let selfPtr = Unmanaged.passRetained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: eventTapCallback,
            userInfo: selfPtr
        ) else {
            showAccessibilityError()
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func showAccessibilityError() {
        let alert = NSAlert()
        alert.messageText = "Требуется разрешение Accessibility"
        alert.informativeText = "Откройте Системные настройки → Конфиденциальность и безопасность → Универсальный доступ и добавьте это приложение."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Открыть настройки")
        alert.addButton(withTitle: "Отмена")
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(
                URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
            )
        }
    }
}
