import SwiftUI
import AppKit

struct SettingsView: View {
    @ObservedObject var settings: SettingsModel

    private var l: L10n { settings.l10n }

    var body: some View {
        Form {
            Section(l.sectionPresets) {
                labeled(l.labelPreset) {
                    Picker("", selection: presetBinding) {
                        ForEach(settings.availablePresets) { preset in
                            Text(preset.title(language: settings.language)).tag(preset.id)
                        }
                        Text(l.labelCustomPreset).tag(CursorPresetLibrary.customID)
                    }
                    .labelsHidden()
                }

                labeled(l.labelStyle) {
                    Picker("", selection: $settings.renderStyle) {
                        ForEach(CursorRenderStyle.allCases) { style in
                            Text(style.displayName(language: settings.language)).tag(style)
                        }
                    }
                    .labelsHidden()
                }

                Text(l.labelPresetHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(l.sectionTrail) {
                labeled(l.labelLength) {
                    Slider(value: $settings.trailLength, in: 20...200, step: 1)
                    Text("\(Int(settings.trailLength))").monoframe(35)
                }
                labeled(l.labelWidth) {
                    Slider(value: $settings.lineWidth, in: 2...80, step: 1)
                    Text("\(Int(settings.lineWidth)) pt").monoframe(45)
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

            Section(l.sectionControl) {
                Toggle(l.labelShortcut, isOn: $settings.globalShortcutEnabled)
                if settings.globalShortcutEnabled {
                    Text("\(HotkeyManager.shared.shortcutDisplayString) — \(l.labelShortcutHint)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Toggle(l.labelLoginItem, isOn: $settings.launchAtLogin)
                if !settings.launchAtLoginStatus.isEmpty {
                    Text(settings.launchAtLoginStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(l.labelLaunchAtLoginHint)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Section(l.sectionApp) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(l.labelCurrentApp)
                        Spacer()
                        Text(currentAppTitle)
                            .foregroundStyle(.secondary)
                    }

                    Button(l.labelAddCurrentApp, action: addCurrentApp)
                        .disabled(!canAddCurrentApp)

                    if !canAddCurrentApp {
                        Text(l.labelCurrentAppUnavailable)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(l.labelExcludedApps)
                    if settings.excludedApps.isEmpty {
                        Text(l.labelNoExcludedApps)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(settings.excludedApps) { app in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(app.displayName)
                                    Text(app.bundleID)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button(role: .destructive) {
                                    settings.removeExcludedApp(bundleID: app.bundleID)
                                } label: {
                                    Image(systemName: "minus.circle")
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                Picker(l.labelLanguage, selection: $settings.language) {
                    ForEach(AppLanguage.allCases) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }
                .pickerStyle(.segmented)

                Text(l.labelPresenterPositioning)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section(l.sectionAbout) {
                HStack {
                    Text(l.labelMadeBy)
                    Spacer()
                    Text("zaitsev-av")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Version")
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")
                        .foregroundStyle(.secondary)
                }
                Button(l.labelSupportBtn) {
                    NSWorkspace.shared.open(URL(string: "https://boosty.to/zaitsev_av")!)
                }
                .buttonStyle(.link)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .padding(.bottom, 8)
    }

    private var presetBinding: Binding<String> {
        Binding(
            get: { settings.selectedPresetID },
            set: { settings.applyPreset(withID: $0) }
        )
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

    private var currentAppTitle: String {
        guard !settings.activeAppName.isEmpty else { return "—" }
        return settings.activeAppName
    }

    private var canAddCurrentApp: Bool {
        !settings.activeAppName.isEmpty &&
        !settings.activeAppBundleID.isEmpty &&
        !settings.isExcluded(bundleID: settings.activeAppBundleID)
    }

    private func addCurrentApp() {
        guard canAddCurrentApp else { return }
        settings.addExcludedApp(bundleID: settings.activeAppBundleID, displayName: settings.activeAppName)
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
