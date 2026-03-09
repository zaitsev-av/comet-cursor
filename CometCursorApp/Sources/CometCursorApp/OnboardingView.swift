import AppKit
import SwiftUI

struct OnboardingView: View {
    @ObservedObject var settings: SettingsModel
    let onComplete: () -> Void

    @State private var isGranted = false
    @State private var pollTimer: Timer?

    private var l: L10n { settings.l10n }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 56, weight: .light))
                    .foregroundStyle(.linearGradient(
                        colors: [Color(nsColor: settings.headColor), Color(nsColor: settings.tailColor)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .padding(.top, 36)

                Text(l.onboardingTitle)
                    .font(.largeTitle.bold())

                Text(l.onboardingSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 40)

            Divider()
                .padding(.vertical, 28)

            // Permission explanation
            HStack(alignment: .top, spacing: 16) {
                Image(systemName: "hand.raised.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)
                    .frame(width: 36, height: 36)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 6) {
                    Text(l.onboardingPermTitle)
                        .font(.headline)
                    Text(l.onboardingPermBody)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 40)

            Spacer().frame(height: 28)

            // Status / action
            Group {
                if isGranted {
                    Label(l.onboardingGranted, systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .foregroundStyle(.green)
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                } else {
                    VStack(spacing: 12) {
                        Button(action: openSystemSettings) {
                            Label(l.onboardingOpenSettings, systemImage: "gear")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)

                        Text(l.onboardingWaiting)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .animation(.easeInOut(duration: 0.3), value: isGranted)
            .padding(.horizontal, 40)

            Spacer().frame(height: 32)

            // Language picker + Skip
            HStack {
                Picker("", selection: $settings.language) {
                    ForEach(AppLanguage.allCases) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 160)

                Spacer()

                Button(l.onboardingSkip, action: onComplete)
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 24)
        }
        .frame(width: 460)
        .onAppear(perform: startPolling)
        .onDisappear(perform: stopPolling)
    }

    private func openSystemSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    private func startPolling() {
        // Already has permission (re-opened onboarding, or granted before window showed)
        if AXIsProcessTrusted() {
            handleGranted()
            return
        }
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if AXIsProcessTrusted() {
                stopPolling()
                handleGranted()
            }
        }
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func handleGranted() {
        isGranted = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            onComplete()
        }
    }
}
