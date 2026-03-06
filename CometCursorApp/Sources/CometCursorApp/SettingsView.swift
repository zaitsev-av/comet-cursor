import SwiftUI
import AppKit

struct SettingsView: View {
    @ObservedObject var settings: SettingsModel

    var body: some View {
        Form {
            Section("Хвост") {
                labeled("Длина") {
                    Slider(value: $settings.trailLength, in: 20...200, step: 1)
                    Text("\(Int(settings.trailLength))").monoframe(35)
                }
                labeled("Толщина") {
                    Slider(value: $settings.lineWidth, in: 2...80, step: 1)
                    Text("\(Int(settings.lineWidth)) px").monoframe(45)
                }
                labeled("Прозрачность") {
                    Slider(value: $settings.opacity, in: 0.1...1.0)
                    Text("\(Int(settings.opacity * 100))%").monoframe(45)
                }
            }

            Section("Затухание") {
                labeled("Скорость") {
                    Slider(value: $settings.fadeSpeed, in: 0.2...3.0)
                    Text(fadeLabel).monoframe(60)
                }
                labeled("Задержка") {
                    Slider(value: $settings.fadeDelay, in: 0.0...2.0)
                    Text(delayLabel).monoframe(60)
                }
            }

            Section("Цвета") {
                ColorPicker("Цвет хвоста", selection: tailColorBinding)
                ColorPicker("Цвет головы", selection: headColorBinding)
            }
        }
        .formStyle(.grouped)
        .frame(width: 400)
        .padding(.bottom, 8)
    }

    private var tailColorBinding: Binding<Color> {
        Binding(
            get: { Color(settings.tailColor) },
            set: { settings.tailColor = NSColor($0) }
        )
    }

    private var headColorBinding: Binding<Color> {
        Binding(
            get: { Color(settings.headColor) },
            set: { settings.headColor = NSColor($0) }
        )
    }

    private var fadeLabel: String {
        switch settings.fadeSpeed {
        case ..<0.7:  return "медленно"
        case ..<1.6:  return "средне"
        default:      return "быстро"
        }
    }

    private var delayLabel: String {
        switch settings.fadeDelay {
        case ..<0.15: return "сразу"
        case ..<0.7:  return "\(String(format: "%.1f", settings.fadeDelay)) с"
        default:      return "\(String(format: "%.1f", settings.fadeDelay)) с"
        }
    }

    @ViewBuilder
    private func labeled<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(label).frame(width: 80, alignment: .leading)
            content()
        }
    }
}

private extension Text {
    func monoframe(_ width: CGFloat) -> some View {
        self.monospacedDigit().frame(width: width, alignment: .trailing)
    }
}
