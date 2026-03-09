import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case en, ru

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .en: return "English"
        case .ru: return "Русский"
        }
    }
}

struct L10n {
    let lang: AppLanguage

    // MARK: - Menu
    var menuEnabled: String     { s("Enabled",           "Включён") }
    var menuSettings: String    { s("Settings\u{2026}",  "Настройки\u{2026}") }
    var menuQuit: String        { s("Quit",              "Выйти") }
    var windowTitle: String     { s("Comet Cursor — Settings", "Comet Cursor — Настройки") }

    // MARK: - Settings sections
    var sectionTrail: String    { s("Trail",         "Хвост") }
    var sectionFade: String     { s("Fade",          "Затухание") }
    var sectionColors: String   { s("Colors",        "Цвета") }
    var sectionApp: String      { s("Application",   "Приложение") }

    // MARK: - Settings labels
    var labelLength: String     { s("Length",        "Длина") }
    var labelWidth: String      { s("Width",         "Толщина") }
    var labelOpacity: String    { s("Opacity",       "Прозрачность") }
    var labelSpeed: String      { s("Speed",         "Скорость") }
    var labelDelay: String      { s("Delay",         "Задержка") }
    var labelTailColor: String  { s("Trail color",   "Цвет хвоста") }
    var labelHeadColor: String  { s("Head color",    "Цвет головы") }
    var labelLanguage: String   { s("Language",      "Язык") }

    // MARK: - Dynamic labels
    func fadeSpeedLabel(_ speed: Double) -> String {
        switch speed {
        case ..<0.7:  return s("slow",   "медленно")
        case ..<1.6:  return s("medium", "средне")
        default:      return s("fast",   "быстро")
        }
    }

    func fadeDelayLabel(_ delay: Double) -> String {
        if delay < 0.15 { return s("instant", "сразу") }
        let unit = s("s", "с")
        return String(format: "%.1f \(unit)", delay)
    }

    // MARK: - Onboarding
    var onboardingTitle: String       { s("Welcome to Comet Cursor",      "Добро пожаловать") }
    var onboardingSubtitle: String    { s("Beautiful cursor trails for your Mac.", "Красивые следы курсора для вашего Mac.") }
    var onboardingPermTitle: String   { s("Accessibility Access Required", "Необходим доступ Accessibility") }
    var onboardingPermBody: String    { s(
        "Comet Cursor uses the Accessibility API to track cursor position across all apps. The data never leaves your device.",
        "Comet Cursor использует Accessibility API для отслеживания положения курсора. Данные не покидают ваше устройство."
    ) }
    var onboardingOpenSettings: String { s("Open System Settings", "Открыть системные настройки") }
    var onboardingWaiting: String     { s("Waiting for permission\u{2026}", "Ожидание разрешения\u{2026}") }
    var onboardingGranted: String     { s("Access granted — let's go!", "Доступ получен — поехали!") }
    var onboardingSkip: String        { s("Skip", "Пропустить") }

    // MARK: - Accessibility error (fallback alert)
    var accessibilityAlertTitle: String { s("Accessibility Permission Required", "Необходимо разрешение Accessibility") }
    var accessibilityAlertBody: String  { s(
        "Open System Settings → Privacy & Security → Accessibility and add Comet Cursor.",
        "Откройте Системные настройки → Конфиденциальность и безопасность → Универсальный доступ и добавьте это приложение."
    ) }
    var accessibilityAlertOpen: String  { s("Open Settings", "Открыть настройки") }
    var accessibilityAlertCancel: String { s("Cancel", "Отмена") }

    // MARK: - Private
    private func s(_ en: String, _ ru: String) -> String {
        lang == .en ? en : ru
    }
}
