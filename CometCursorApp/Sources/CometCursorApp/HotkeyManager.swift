import Carbon.HIToolbox
import Foundation

private let toggleHotKeySignature = fourCharCode("CMTC")
private let toggleHotKeyID: UInt32 = 1

private func fourCharCode(_ value: String) -> OSType {
    value.utf8.reduce(0) { ($0 << 8) | OSType($1) }
}

private func hotKeyEventHandler(
    _ nextHandler: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event else { return noErr }

    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )

    guard status == noErr, hotKeyID.signature == toggleHotKeySignature else {
        return noErr
    }

    HotkeyManager.shared.handleHotKeyPress(id: hotKeyID.id)
    return noErr
}

final class HotkeyManager {
    static let shared = HotkeyManager()

    let shortcutDisplayString = "⌥⌘C"

    var onToggle: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    private init() {}

    func setEnabled(_ enabled: Bool) {
        installHandlerIfNeeded()
        enabled ? registerToggleShortcut() : unregisterToggleShortcut()
    }

    private func installHandlerIfNeeded() {
        guard eventHandlerRef == nil else { return }

        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        InstallEventHandler(
            GetApplicationEventTarget(),
            hotKeyEventHandler,
            1,
            &eventSpec,
            nil,
            &eventHandlerRef
        )
    }

    private func registerToggleShortcut() {
        guard hotKeyRef == nil else { return }

        let hotKeyID = EventHotKeyID(signature: toggleHotKeySignature, id: toggleHotKeyID)
        RegisterEventHotKey(
            UInt32(kVK_ANSI_C),
            UInt32(optionKey | cmdKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }

    private func unregisterToggleShortcut() {
        guard let hotKeyRef else { return }
        UnregisterEventHotKey(hotKeyRef)
        self.hotKeyRef = nil
    }

    fileprivate func handleHotKeyPress(id: UInt32) {
        guard id == toggleHotKeyID else { return }
        DispatchQueue.main.async { self.onToggle?() }
    }
}
