import Foundation
import ServiceManagement

final class LaunchAtLoginManager {
    static let shared = LaunchAtLoginManager()

    private init() {}

    func currentStatusMessage(language: AppLanguage) -> String {
        if #available(macOS 13.0, *) {
            switch SMAppService.mainApp.status {
            case .enabled:
                return language == .en
                    ? "Launch at login is enabled."
                    : "Запуск при входе включён."
            case .requiresApproval:
                return language == .en
                    ? "Approve Comet Cursor in Login Items to finish setup."
                    : "Подтвердите Comet Cursor в объектах входа, чтобы завершить настройку."
            case .notFound:
                return language == .en
                    ? "Launch at login is unavailable in this build."
                    : "В этой сборке запуск при входе недоступен."
            case .notRegistered:
                return language == .en
                    ? "Launch at login is disabled."
                    : "Запуск при входе выключен."
            @unknown default:
                return language == .en
                    ? "Launch at login status is unavailable."
                    : "Статус запуска при входе недоступен."
            }
        }

        return language == .en
            ? "Launch at login requires macOS 13 or newer."
            : "Запуск при входе требует macOS 13 или новее."
    }

    @discardableResult
    func applyPreference(_ enabled: Bool, language: AppLanguage) -> String {
        guard #available(macOS 13.0, *) else {
            return currentStatusMessage(language: language)
        }

        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            return currentStatusMessage(language: language)
        } catch {
            return language == .en
                ? "Launch at login update failed: \(error.localizedDescription)"
                : "Не удалось обновить запуск при входе: \(error.localizedDescription)"
        }
    }
}
