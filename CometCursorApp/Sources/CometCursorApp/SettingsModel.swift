import AppKit
import Foundation
import simd

enum CursorRenderStyle: String, CaseIterable, Identifiable {
    case comet
    case neon
    case minimal

    var id: String { rawValue }

    var shaderValue: Int32 {
        switch self {
        case .comet: return 0
        case .neon: return 1
        case .minimal: return 2
        }
    }

    func displayName(language: AppLanguage) -> String {
        switch (self, language) {
        case (.comet, .en): return "Comet"
        case (.comet, .ru): return "Комета"
        case (.neon, .en): return "Neon"
        case (.neon, .ru): return "Неон"
        case (.minimal, .en): return "Minimal"
        case (.minimal, .ru): return "Минимализм"
        }
    }
}

struct AppExclusion: Codable, Equatable, Identifiable {
    let bundleID: String
    let displayName: String

    var id: String { bundleID }
}

struct CursorPreset: Identifiable {
    let id: String
    let titleEN: String
    let titleRU: String
    let style: CursorRenderStyle
    let trailLength: Double
    let lineWidth: Double
    let fadeSpeed: Double
    let opacity: Double
    let fadeDelay: Double
    let tailColor: NSColor
    let headColor: NSColor

    func title(language: AppLanguage) -> String {
        language == .en ? titleEN : titleRU
    }
}

enum CursorPresetLibrary {
    static let customID = "custom"

    static let presets: [CursorPreset] = [
        CursorPreset(
            id: "presenter",
            titleEN: "Presenter Glow",
            titleRU: "Презентация",
            style: .comet,
            trailLength: 84,
            lineWidth: 16,
            fadeSpeed: 0.95,
            opacity: 0.96,
            fadeDelay: 0.45,
            tailColor: NSColor(red: 0.96, green: 0.41, blue: 0.08, alpha: 1),
            headColor: NSColor(red: 1.00, green: 0.96, blue: 0.42, alpha: 1)
        ),
        CursorPreset(
            id: "neon",
            titleEN: "Neon Focus",
            titleRU: "Неоновый фокус",
            style: .neon,
            trailLength: 96,
            lineWidth: 18,
            fadeSpeed: 1.15,
            opacity: 0.92,
            fadeDelay: 0.35,
            tailColor: NSColor(red: 0.08, green: 0.77, blue: 0.96, alpha: 1),
            headColor: NSColor(red: 0.72, green: 0.95, blue: 1.00, alpha: 1)
        ),
        CursorPreset(
            id: "minimal",
            titleEN: "Minimal Trace",
            titleRU: "Тонкий след",
            style: .minimal,
            trailLength: 52,
            lineWidth: 8,
            fadeSpeed: 1.55,
            opacity: 0.72,
            fadeDelay: 0.18,
            tailColor: NSColor(red: 0.41, green: 0.41, blue: 0.45, alpha: 1),
            headColor: NSColor(red: 0.94, green: 0.94, blue: 0.97, alpha: 1)
        )
    ]

    static func preset(id: String) -> CursorPreset? {
        presets.first(where: { $0.id == id })
    }
}

final class SettingsModel: ObservableObject {
    private var isApplyingPreset = false

    @Published var language: AppLanguage {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: "language") }
    }
    var l10n: L10n { L10n(lang: language) }

    @Published var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: "isEnabled") }
    }
    @Published var selectedPresetID: String {
        didSet { UserDefaults.standard.set(selectedPresetID, forKey: "selectedPresetID") }
    }
    @Published var renderStyle: CursorRenderStyle {
        didSet {
            UserDefaults.standard.set(renderStyle.rawValue, forKey: "renderStyle")
            markPresetAsCustomIfNeeded()
        }
    }
    @Published var trailLength: Double {
        didSet {
            UserDefaults.standard.set(trailLength, forKey: "trailLength")
            markPresetAsCustomIfNeeded()
        }
    }
    @Published var lineWidth: Double {
        didSet {
            UserDefaults.standard.set(lineWidth, forKey: "lineWidth")
            markPresetAsCustomIfNeeded()
        }
    }
    @Published var fadeSpeed: Double {
        didSet {
            UserDefaults.standard.set(fadeSpeed, forKey: "fadeSpeed")
            markPresetAsCustomIfNeeded()
        }
    }
    @Published var opacity: Double {
        didSet {
            UserDefaults.standard.set(opacity, forKey: "opacity")
            markPresetAsCustomIfNeeded()
        }
    }
    @Published var fadeDelay: Double {
        didSet {
            UserDefaults.standard.set(fadeDelay, forKey: "fadeDelay")
            markPresetAsCustomIfNeeded()
        }
    }
    @Published var tailColor: NSColor {
        didSet {
            saveColor(tailColor, key: "tailColor")
            markPresetAsCustomIfNeeded()
        }
    }
    @Published var headColor: NSColor {
        didSet {
            saveColor(headColor, key: "headColor")
            markPresetAsCustomIfNeeded()
        }
    }
    @Published var globalShortcutEnabled: Bool {
        didSet { UserDefaults.standard.set(globalShortcutEnabled, forKey: "globalShortcutEnabled") }
    }
    @Published var launchAtLogin: Bool {
        didSet { UserDefaults.standard.set(launchAtLogin, forKey: "launchAtLogin") }
    }
    @Published var excludedApps: [AppExclusion] {
        didSet { saveExcludedApps(excludedApps) }
    }
    @Published var activeAppName: String = ""
    @Published var activeAppBundleID: String = ""
    @Published var launchAtLoginStatus: String = ""

    init() {
        let rawLang = ud.string(forKey: "language") ?? AppLanguage.en.rawValue
        language = AppLanguage(rawValue: rawLang) ?? .en
        isEnabled = ud.boolOrDefault(key: "isEnabled", default: true)
        selectedPresetID = ud.string(forKey: "selectedPresetID") ?? "presenter"
        renderStyle = CursorRenderStyle(rawValue: ud.string(forKey: "renderStyle") ?? CursorRenderStyle.comet.rawValue) ?? .comet
        trailLength = ud.doubleOrDefault(key: "trailLength", default: 80)
        lineWidth = ud.doubleOrDefault(key: "lineWidth", default: 12)
        let rawFadeSpeed = ud.doubleOrDefault(key: "fadeSpeed", default: 0.9)
        fadeSpeed = rawFadeSpeed < 0.1 ? rawFadeSpeed * 60 : rawFadeSpeed
        opacity = ud.doubleOrDefault(key: "opacity", default: 0.92)
        fadeDelay = ud.doubleOrDefault(key: "fadeDelay", default: 0.4)
        tailColor = loadColor(key: "tailColor") ?? NSColor(red: 0.6, green: 0.1, blue: 0.0, alpha: 1)
        headColor = loadColor(key: "headColor") ?? NSColor(red: 1.0, green: 1.0, blue: 0.4, alpha: 1)
        globalShortcutEnabled = ud.boolOrDefault(key: "globalShortcutEnabled", default: true)
        launchAtLogin = ud.boolOrDefault(key: "launchAtLogin", default: false)
        excludedApps = Self.loadExcludedApps()

        if CursorPresetLibrary.preset(id: selectedPresetID) != nil {
            applyPreset(withID: selectedPresetID, persistSelection: false)
        } else {
            selectedPresetID = CursorPresetLibrary.customID
        }
    }

    var availablePresets: [CursorPreset] { CursorPresetLibrary.presets }
    var tailColorSIMD: SIMD4<Float> { simd(tailColor) }
    var headColorSIMD: SIMD4<Float> { simd(headColor) }

    func applyPreset(withID id: String, persistSelection: Bool = true) {
        guard let preset = CursorPresetLibrary.preset(id: id) else {
            selectedPresetID = CursorPresetLibrary.customID
            return
        }

        isApplyingPreset = true
        renderStyle = preset.style
        trailLength = preset.trailLength
        lineWidth = preset.lineWidth
        fadeSpeed = preset.fadeSpeed
        opacity = preset.opacity
        fadeDelay = preset.fadeDelay
        tailColor = preset.tailColor
        headColor = preset.headColor
        isApplyingPreset = false

        if persistSelection {
            selectedPresetID = preset.id
        }
    }

    func addExcludedApp(bundleID: String, displayName: String) {
        guard !bundleID.isEmpty, !isExcluded(bundleID: bundleID) else { return }
        excludedApps.append(AppExclusion(bundleID: bundleID, displayName: displayName))
        excludedApps.sort { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    func removeExcludedApp(bundleID: String) {
        excludedApps.removeAll { $0.bundleID == bundleID }
    }

    func isExcluded(bundleID: String?) -> Bool {
        guard let bundleID, !bundleID.isEmpty else { return false }
        return excludedApps.contains(where: { $0.bundleID == bundleID })
    }

    func setActiveApplication(name: String, bundleID: String) {
        activeAppName = name
        activeAppBundleID = bundleID
    }

    func updateLaunchAtLoginStatus(_ message: String) {
        launchAtLoginStatus = message
    }

    private func markPresetAsCustomIfNeeded() {
        guard !isApplyingPreset, selectedPresetID != CursorPresetLibrary.customID else { return }
        selectedPresetID = CursorPresetLibrary.customID
    }

    private func simd(_ color: NSColor) -> SIMD4<Float> {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        (color.usingColorSpace(.sRGB) ?? color).getRed(&r, green: &g, blue: &b, alpha: &a)
        return SIMD4<Float>(Float(r), Float(g), Float(b), Float(a))
    }

    private func saveColor(_ color: NSColor, key: String) {
        if let data = try? NSKeyedArchiver.archivedData(withRootObject: color, requiringSecureCoding: false) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func saveExcludedApps(_ apps: [AppExclusion]) {
        if let data = try? JSONEncoder().encode(apps) {
            UserDefaults.standard.set(data, forKey: "excludedApps")
        }
    }

    private static func loadExcludedApps() -> [AppExclusion] {
        guard let data = UserDefaults.standard.data(forKey: "excludedApps"),
              let apps = try? JSONDecoder().decode([AppExclusion].self, from: data) else {
            return []
        }
        return apps
    }
}

private func loadColor(key: String) -> NSColor? {
    guard let data = UserDefaults.standard.data(forKey: key),
          let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data)
    else { return nil }
    return color
}

private let ud = UserDefaults.standard

private extension UserDefaults {
    func boolOrDefault(key: String, default value: Bool) -> Bool {
        object(forKey: key) == nil ? value : bool(forKey: key)
    }

    func doubleOrDefault(key: String, default value: Double) -> Double {
        object(forKey: key) == nil ? value : double(forKey: key)
    }
}
