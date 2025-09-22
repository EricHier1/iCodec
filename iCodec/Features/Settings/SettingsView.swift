import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        ZStack {
            themeManager.backgroundColor
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    themeSettingsSection
                    systemSettingsSection
                    aboutSection
                }
                .padding(.vertical, 20)
            }
        }
        .overlay(
            ScanlineOverlay()
                .opacity(0.1)
        )
    }

    private var themeSettingsSection: some View {
        HUDPanel(title: "Visual Mode") {
            VStack(spacing: 12) {
                ForEach(CodecTheme.allCases, id: \.self) { theme in
                    HStack {
                        Text(theme.name)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(themeManager.textColor)

                        Spacer()

                        Circle()
                            .fill(theme.primaryColor)
                            .frame(width: 12, height: 12)

                        if themeManager.currentTheme == theme {
                            Text("ACTIVE")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(themeManager.successColor)
                        } else {
                            CodecButton(title: "SELECT", action: {
                                themeManager.switchTheme(to: theme)
                            }, style: .secondary, size: .small)
                        }
                    }
                }
            }
        }
    }

    private var systemSettingsSection: some View {
        HUDPanel(title: "System Config") {
            VStack(spacing: 12) {
                settingRow("GPS TRACKING", status: "ENABLED")
                settingRow("CAMERA ACCESS", status: "ENABLED")
                settingRow("MICROPHONE", status: "ENABLED")
                settingRow("NOTIFICATIONS", status: "ENABLED")
            }
        }
    }

    private var aboutSection: some View {
        HUDPanel(title: "System Info") {
            VStack(alignment: .leading, spacing: 8) {
                Text("iCodec v1.0.0")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(themeManager.primaryColor)

                Text("Tactical Espionage Terminal")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(themeManager.textColor.opacity(0.7))

                Text("Compatible with iOS 17+")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(themeManager.textColor.opacity(0.7))
            }
        }
    }

    private func settingRow(_ setting: String, status: String) -> some View {
        HStack {
            Text(setting)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(themeManager.textColor)

            Spacer()

            Text(status)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(themeManager.successColor)
        }
    }
}