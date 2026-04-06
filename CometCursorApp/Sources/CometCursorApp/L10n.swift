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
    var menuEnabled: String     { s("Enabled",                    "Включён") }
    var menuSettings: String    { s("Settings\u{2026}",           "Настройки\u{2026}") }
    var menuSupport: String     { s("Support on Boosty \u{2197}", "Поддержать на Boosty \u{2197}") }
    var menuQuit: String        { s("Quit",                       "Выйти") }
    var windowTitle: String     { s("Comet Cursor — Settings",    "Comet Cursor — Настройки") }

    // MARK: - Settings sections
    var sectionPresets: String  { s("Quick Start",    "Быстрый старт") }
    var sectionTrail: String    { s("Trail",         "Хвост") }
    var sectionFade: String     { s("Fade",          "Затухание") }
    var sectionColors: String   { s("Colors",        "Цвета") }
    var sectionControl: String  { s("Control",       "Управление") }
    var sectionApp: String      { s("Application",   "Приложение") }

    // MARK: - Settings labels
    var labelPreset: String     { s("Preset",        "Пресет") }
    var labelStyle: String      { s("Style",         "Стиль") }
    var labelLength: String     { s("Length",        "Длина") }
    var labelWidth: String      { s("Width",         "Толщина") }
    var labelOpacity: String    { s("Opacity",       "Прозрачность") }
    var labelSpeed: String      { s("Speed",         "Скорость") }
    var labelDelay: String      { s("Delay",         "Задержка") }
    var labelTailColor: String  { s("Trail color",   "Цвет хвоста") }
    var labelHeadColor: String  { s("Head color",    "Цвет головы") }
    var labelLanguage: String   { s("Language",      "Язык") }
    var labelShortcut: String   { s("Global shortcut", "Глобальная клавиша") }
    var labelLoginItem: String  { s("Launch at login", "Запуск при входе") }
    var labelExcludedApps: String { s("Hidden in apps", "Скрывать в приложениях") }
    var labelCurrentApp: String { s("Current app", "Текущее приложение") }
    var labelPresetHint: String { s("Pick a ready-made look for demos, recordings, and calls.", "Выберите готовый стиль для демо, записей и созвонов.") }
    var labelShortcutHint: String { s("Use a system-wide shortcut to pause or resume the cursor effect instantly.", "Используйте системное сочетание, чтобы мгновенно включать или ставить эффект на паузу.") }
    var labelNoExcludedApps: String { s("No exclusions yet.", "Список исключений пока пуст.") }
    var labelCustomPreset: String { s("Custom", "Свои настройки") }
    var labelAddCurrentApp: String { s("Hide in current app", "Скрывать в текущем приложении") }
    var labelCurrentAppUnavailable: String { s("Open another app to add it here.", "Откройте другое приложение, чтобы добавить его сюда.") }
    var labelLaunchAtLoginHint: String { s("Best for menu bar workflows after you sign the app bundle.", "Лучше всего работает после подписи app bundle.") }
    var labelPresenterPositioning: String { s("Built for screen sharing, demos, and recordings.", "Сделано для демонстраций экрана, демо и записей.") }

    // MARK: - About
    var sectionAbout: String       { s("About",            "О приложении") }
    var labelMadeBy: String        { s("Made by",          "Автор") }
    var labelSupportBtn: String    { s("Support on Boosty \u{2197}", "Поддержать на Boosty \u{2197}") }

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
    var onboardingTitle: String       { s("Make your cursor easy to follow",      "Сделайте курсор заметным") }
    var onboardingSubtitle: String    { s("Comet Cursor keeps attention on your pointer during demos, calls, and screen recordings.", "Comet Cursor помогает следить за курсором во время демо, созвонов и записи экрана.") }
    var onboardingPermTitle: String   { s("Accessibility improves tracking", "Accessibility улучшает отслеживание") }
    var onboardingPermBody: String    { s(
        "Accessibility gives Comet Cursor the smoothest cross-app tracking. You can continue without it and upgrade later in System Settings. Your data never leaves your Mac.",
        "Accessibility даёт Comet Cursor самое плавное отслеживание во всех приложениях. Можно продолжить и без него, а затем включить доступ позже в системных настройках. Данные не покидают ваш Mac."
    ) }
    var onboardingOpenSettings: String { s("Open System Settings", "Открыть системные настройки") }
    var onboardingWaiting: String     { s("Waiting for permission\u{2026}", "Ожидание разрешения\u{2026}") }
    var onboardingGranted: String     { s("Access granted — you're ready to present.", "Доступ получен — можно показывать экран.") }
    var onboardingSkip: String        { s("Continue without access", "Продолжить без доступа") }

    // MARK: - Accessibility error (fallback alert)
    var accessibilityAlertTitle: String { s("Accessibility Permission Required", "Необходимо разрешение Accessibility") }
    var accessibilityAlertBody: String  { s(
        "Open System Settings → Privacy & Security → Accessibility and add Comet Cursor for smoother cross-app tracking.",
        "Откройте Системные настройки → Конфиденциальность и безопасность → Универсальный доступ и добавьте это приложение для более плавного отслеживания."
    ) }
    var accessibilityAlertOpen: String  { s("Open Settings", "Открыть настройки") }
    var accessibilityAlertCancel: String { s("Cancel", "Отмена") }

    // MARK: - Private
    private func s(_ en: String, _ ru: String) -> String {
        lang == .en ? en : ru
    }
}
