import SwiftUI
import AppKit

struct SettingsView: View {
    @ObservedObject var settings: SettingsModel

    private var l: L10n { settings.l10n }

    var body: some View {
        Form {
            Section(l.sectionTrail) {
                labeled(l.labelLength) {
                    Slider(value: $settings.trailLength, in: 20...200, step: 1)
                    Text("\(Int(settings.trailLength))").monoframe(35)
                }
                labeled(l.labelWidth) {
                    Slider(value: $settings.lineWidth, in: 2...80, step: 1)
                    Text("\(Int(settings.lineWidth)) px").monoframe(45)
                }
                labeled(l.labelOpacity) {
                    Slider(value: $settings.opacity, in: 0.1...1.0)
                    Text("\(Int(settings.opacity * 100))%").monoframe(45)
                }
            }

            Section(l.sectionFade) {
                labeled(l.labelSpeed) {
                    Slider(value: $settings.fadeSpeed, in: 0.2...3.0)
                    Text(l.fadeSpeedLabel(settings.fadeSpeed)).monoframe(60)
                }
                labeled(l.labelDelay) {
                    Slider(value: $settings.fadeDelay, in: 0.0...2.0)
                    Text(l.fadeDelayLabel(settings.fadeDelay)).monoframe(60)
                }
            }

            Section(l.sectionColors) {
                ColorPicker(l.labelTailColor, selection: tailColorBinding)
                ColorPicker(l.labelHeadColor, selection: headColorBinding)
            }

            Section(l.sectionApp) {
                Picker(l.labelLanguage, selection: $settings.language) {
                    ForEach(AppLanguage.allCases) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }
                .pickerStyle(.segmented)
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

    @ViewBuilder
    private func labeled<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(label).frame(width: 90, alignment: .leading)
            content()
        }
    }
}

private extension Text {
    func monoframe(_ width: CGFloat) -> some View {
        self.monospacedDigit().frame(width: width, alignment: .trailing)
    }
}
