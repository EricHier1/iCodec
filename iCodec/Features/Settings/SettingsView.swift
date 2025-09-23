import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var customPrimaryHex = ""
    @State private var customSecondaryHex = ""
    @State private var customAccentHex = ""
    @State private var customThemeError: String?
    @State private var tabOrder: [AppModule] = AppModule.navigationModules

    var body: some View {
        ZStack {
            themeManager.backgroundColor
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    themeSettingsSection
                    tabOrderSection
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
        .onAppear {
            syncCustomInputs()
            tabOrder = AppModule.navigationModules
        }
        .onChange(of: themeManager.customPalette) {
            syncCustomInputs()
        }
    }

    private var themeSettingsSection: some View {
        HUDPanel(title: "HUD Color Scheme") {
            VStack(spacing: 16) {
                ForEach(CodecTheme.allCases, id: \.self) { theme in
                    VStack(spacing: 8) {
                        let palette = themeManager.palette(for: theme)

                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(theme.name)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(themeManager.textColor)
                                    .fontWeight(.bold)

                                Text(theme.description)
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundColor(themeManager.textColor.opacity(0.7))
                            }

                            Spacer()

                            // Color preview
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(palette.primary)
                                    .frame(width: 10, height: 10)
                                Circle()
                                    .fill(palette.accent)
                                    .frame(width: 10, height: 10)
                                Circle()
                                    .fill(palette.secondary)
                                    .frame(width: 10, height: 10)
                            }

                            if themeManager.currentTheme == theme {
                                Text("ACTIVE")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(themeManager.successColor)
                                    .fontWeight(.bold)
                            } else {
                                CodecButton(title: "SELECT", action: {
                                    themeManager.switchTheme(to: theme)
                                }, style: .secondary, size: .small)
                            }
                        }

                        if theme == .custom {
                            customThemeConfigurator
                        }

                        if themeManager.currentTheme != theme {
                            Divider()
                                .background(themeManager.primaryColor.opacity(0.3))
                        }
                    }
                }
            }
        }
    }

    private var tabOrderSection: some View {
        HUDPanel(title: "Tab Order Configuration") {
            VStack(spacing: 16) {
                Text("DRAG TO REORDER NAVIGATION TABS")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(themeManager.textColor.opacity(0.7))
                    .fontWeight(.bold)

                VStack(spacing: 8) {
                    ForEach(Array(tabOrder.enumerated()), id: \.element) { index, module in
                        HStack(spacing: 12) {
                            // Drag handle
                            Image(systemName: "line.3.horizontal")
                                .font(.system(size: 12))
                                .foregroundColor(themeManager.primaryColor.opacity(0.6))

                            // Module info
                            HStack(spacing: 8) {
                                Text(module.glyph)
                                    .font(.system(size: 10, design: .monospaced))
                                    .fontWeight(.bold)
                                    .foregroundColor(themeManager.backgroundColor)
                                    .frame(width: 24, height: 16)
                                    .background(themeManager.primaryColor)
                                    .cornerRadius(3)

                                Text(module.rawValue)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(themeManager.textColor)
                                    .fontWeight(.medium)

                                Spacer()

                                Text("#\(index + 1)")
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundColor(themeManager.primaryColor.opacity(0.7))
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(themeManager.surfaceColor.opacity(0.2))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(themeManager.primaryColor.opacity(0.3), lineWidth: 1)
                        )
                        .cornerRadius(6)
                        .onDrag {
                            NSItemProvider(object: "\(index)" as NSString)
                        }
                        .onDrop(of: [.text], delegate: TabDropDelegate(
                            destinationIndex: index,
                            tabOrder: $tabOrder,
                            onReorder: saveTabOrder
                        ))
                    }
                }

                HStack(spacing: 12) {
                    CodecButton(title: "RESET TO DEFAULT", action: {
                        withAnimation(.spring()) {
                            tabOrder = AppModule.defaultNavigationModules
                            saveTabOrder()
                        }
                    }, style: .secondary, size: .small)

                    CodecButton(title: "SAVE ORDER", action: {
                        saveTabOrder()
                    }, style: .primary, size: .small)
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

    private var customThemeConfigurator: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Custom Hex Values")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(themeManager.textColor.opacity(0.7))

            VStack(spacing: 8) {
                hexField(label: "Primary", text: $customPrimaryHex)
                hexField(label: "Secondary", text: $customSecondaryHex)
                hexField(label: "Accent", text: $customAccentHex)
            }

            if let error = customThemeError {
                Text(error)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(themeManager.errorColor)
            }

            CodecButton(
                title: "APPLY",
                action: applyCustomTheme,
                style: .primary,
                size: .fullWidth
            )
        }
        .padding(12)
        .background(themeManager.surfaceColor.opacity(0.4))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(themeManager.primaryColor.opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(8)
    }

    private func hexField(label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(themeManager.textColor.opacity(0.7))

            TextField("#RRGGBB", text: Binding(
                get: { text.wrappedValue },
                set: { newValue in
                    text.wrappedValue = sanitizeHexInput(newValue)
                }
            ))
            .textInputAutocapitalization(.characters)
            .autocorrectionDisabled(true)
            .textFieldStyle(CodecTextFieldStyle())
        }
    }

    private func applyCustomTheme() {
        let success = themeManager.applyCustomPalette(
            primaryHex: customPrimaryHex,
            secondaryHex: customSecondaryHex,
            accentHex: customAccentHex
        )

        if success {
            customThemeError = nil
            syncCustomInputs()
            themeManager.switchTheme(to: .custom)
        } else {
            customThemeError = "Use 6 or 8 digit hex values (e.g. #00FF00)."
        }
    }

    private func syncCustomInputs() {
        customPrimaryHex = themeManager.customPalette.primaryHex
        customSecondaryHex = themeManager.customPalette.secondaryHex
        customAccentHex = themeManager.customPalette.accentHex
    }

    private func sanitizeHexInput(_ value: String) -> String {
        var cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let allowedCharacters = CharacterSet(charactersIn: "0123456789ABCDEF")

        if cleaned.contains("#") {
            cleaned = cleaned.replacingOccurrences(of: "#", with: "")
            cleaned = "#" + cleaned
        }

        if cleaned.hasPrefix("#") {
            let hex = cleaned.dropFirst().unicodeScalars.filter { allowedCharacters.contains($0) }
            cleaned = "#" + String(String.UnicodeScalarView(hex).prefix(8))
        } else {
            let filtered = cleaned.unicodeScalars.filter { allowedCharacters.contains($0) }
            cleaned = String(String.UnicodeScalarView(filtered).prefix(8))
        }

        return cleaned
    }

    private func saveTabOrder() {
        AppModule.saveCustomTabOrder(tabOrder)
        TacticalSoundPlayer.playAction()
    }
}

struct TabDropDelegate: DropDelegate {
    let destinationIndex: Int
    @Binding var tabOrder: [AppModule]
    let onReorder: () -> Void

    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        guard let item = info.itemProviders(for: [.text]).first else { return false }

        item.loadItem(forTypeIdentifier: "public.text", options: nil) { (data, error) in
            if let data = data as? Data,
               let sourceIndexString = String(data: data, encoding: .utf8),
               let sourceIndex = Int(sourceIndexString) {

                DispatchQueue.main.async {
                    if sourceIndex != destinationIndex {
                        let sourceModule = tabOrder[sourceIndex]
                        tabOrder.remove(at: sourceIndex)

                        let actualDestination = sourceIndex < destinationIndex ? destinationIndex - 1 : destinationIndex
                        tabOrder.insert(sourceModule, at: actualDestination)

                        onReorder()
                    }
                }
            }
        }
        return true
    }
}
