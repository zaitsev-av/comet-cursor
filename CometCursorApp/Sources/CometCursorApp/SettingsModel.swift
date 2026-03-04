import AppKit
import Foundation
import simd

class SettingsModel: ObservableObject {

    @Published var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: "isEnabled") }
    }
    @Published var trailLength: Double {
        didSet { UserDefaults.standard.set(trailLength, forKey: "trailLength") }
    }
    @Published var lineWidth: Double {
        didSet { UserDefaults.standard.set(lineWidth, forKey: "lineWidth") }
    }
    @Published var fadeSpeed: Double {
        didSet { UserDefaults.standard.set(fadeSpeed, forKey: "fadeSpeed") }
    }
    @Published var tailColor: NSColor {
        didSet { saveColor(tailColor, key: "tailColor") }
    }
    @Published var headColor: NSColor {
        didSet { saveColor(headColor, key: "headColor") }
    }

    init() {
        isEnabled  = ud.boolOrDefault(key: "isEnabled",   default: true)
        trailLength = ud.doubleOrDefault(key: "trailLength", default: 80)
        lineWidth  = ud.doubleOrDefault(key: "lineWidth",   default: 12)
        fadeSpeed  = ud.doubleOrDefault(key: "fadeSpeed",   default: 0.015)
        tailColor  = loadColor(key: "tailColor")  ?? NSColor(red: 0.6, green: 0.1, blue: 0.0, alpha: 1)
        headColor  = loadColor(key: "headColor")  ?? NSColor(red: 1.0, green: 1.0, blue: 0.4, alpha: 1)
    }

    var tailColorSIMD: SIMD4<Float> { simd(tailColor) }
    var headColorSIMD: SIMD4<Float> { simd(headColor) }

    private func simd(_ color: NSColor) -> SIMD4<Float> {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        (color.usingColorSpace(.sRGB) ?? color).getRed(&r, green: &g, blue: &b, alpha: &a)
        return SIMD4<Float>(Float(r), Float(g), Float(b), Float(a))
    }

    private func saveColor(_ color: NSColor, key: String) {
        if let data = try? NSKeyedArchiver.archivedData(withRootObject: color, requiringSecureCoding: false) {
            UserDefaults.standard.set(data, forKey: key)
        }
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
