import SwiftUI
import Combine
import AudioToolbox

enum TacticalSoundPlayer {
    static func playNavigation() {
        AudioServicesPlaySystemSound(1104)
    }

    static func playAction() {
        AudioServicesPlaySystemSound(1156)
    }

    static func playCodecBuzz() {
        // Metal Gear Solid-style codec buzzing sound with multiple tones
        AudioServicesPlaySystemSound(1007) // Tock sound

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            AudioServicesPlaySystemSound(1016) // Alert tone
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            AudioServicesPlaySystemSound(1519) // Peek haptic
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            AudioServicesPlaySystemSound(1520) // Pop haptic
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            AudioServicesPlaySystemSound(1007) // Tock sound again
        }
    }

    static func playAlert() {
        AudioServicesPlaySystemSound(1005) // New mail sound
    }

    static func playSuccess() {
        AudioServicesPlaySystemSound(1057) // Success sound
    }

    static func playSystemInit() {
        // Subtle initialization sound - softer than action sound
        AudioServicesPlaySystemSound(1103) // Begin recording sound - subtle and professional
    }
}

@MainActor
class ThemeManager: ObservableObject {
    @Published var currentTheme: CodecTheme = .tactical
    @Published var customPalette = CustomThemePalette()

    private var currentPalette: ThemePalette {
        palette(for: currentTheme)
    }

    init() {
        loadPersistedTheme()
    }

    var primaryColor: Color { currentPalette.primary }
    var secondaryColor: Color { currentPalette.secondary }
    var accentColor: Color { currentPalette.accent }
    var backgroundColor: Color { currentPalette.background }
    var surfaceColor: Color { currentPalette.surface }
    var textColor: Color { currentPalette.text }
    var successColor: Color { currentPalette.success }
    var warningColor: Color { currentPalette.warning }
    var errorColor: Color { currentPalette.error }

    func switchTheme(to theme: CodecTheme) {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentTheme = theme
            saveTheme()
        }
    }

    @discardableResult
    func applyCustomPalette(primaryHex: String, secondaryHex: String, accentHex: String) -> Bool {
        guard let normalizedPrimary = Self.normalizeHex(primaryHex),
              let normalizedSecondary = Self.normalizeHex(secondaryHex),
              let normalizedAccent = Self.normalizeHex(accentHex) else {
            return false
        }

        customPalette = CustomThemePalette(
            primaryHex: normalizedPrimary,
            secondaryHex: normalizedSecondary,
            accentHex: normalizedAccent
        )

        saveCustomPalette()
        return true
    }

    func palette(for theme: CodecTheme) -> ThemePalette {
        switch theme {
        case .tactical:
            return ThemePalette.makeDefault(
                primary: Color(red: 0.0, green: 0.8, blue: 0.0),
                secondary: Color(red: 0.0, green: 0.4, blue: 0.0),
                accent: Color(red: 0.2, green: 1.0, blue: 0.2)
            )
        case .night:
            return ThemePalette.makeDefault(
                primary: Color(red: 0.0, green: 0.6, blue: 0.8),
                secondary: Color(red: 0.0, green: 0.3, blue: 0.4),
                accent: Color(red: 0.2, green: 0.8, blue: 1.0)
            )
        case .infrared:
            return ThemePalette.makeDefault(
                primary: Color(red: 1.0, green: 0.4, blue: 0.0),
                secondary: Color(red: 0.6, green: 0.2, blue: 0.0),
                accent: Color(red: 1.0, green: 0.6, blue: 0.2)
            )
        case .custom:
            return ThemePalette.makeDefault(
                primary: customPalette.primaryColor,
                secondary: customPalette.secondaryColor,
                accent: customPalette.accentColor
            )
        }
    }

    static func normalizeHex(_ hex: String) -> String? {
        var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        if cleaned.hasPrefix("#") {
            cleaned.removeFirst()
        }

        guard cleaned.count == 6 || cleaned.count == 8,
              UInt64(cleaned, radix: 16) != nil else {
            return nil
        }

        return "#" + cleaned
    }

    private func saveTheme() {
        UserDefaults.standard.set(currentTheme.rawValue, forKey: "selected_theme")
    }

    private func saveCustomPalette() {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(customPalette) {
            UserDefaults.standard.set(encoded, forKey: "custom_theme_palette")
        }
    }

    private func loadPersistedTheme() {
        // Load custom palette first
        if let data = UserDefaults.standard.data(forKey: "custom_theme_palette"),
           let decoded = try? JSONDecoder().decode(CustomThemePalette.self, from: data) {
            customPalette = decoded
        }

        // Load selected theme
        if let themeName = UserDefaults.standard.string(forKey: "selected_theme"),
           let theme = CodecTheme(rawValue: themeName) {
            currentTheme = theme
        }
    }
}

enum CodecTheme: String, CaseIterable {
    case tactical = "tactical"
    case night = "night"
    case infrared = "infrared"
    case custom = "custom"

    static var allCases: [CodecTheme] {
        [.tactical, .night, .infrared, .custom]
    }

    var name: String {
        switch self {
        case .tactical: return "Tactical"
        case .night: return "Night Vision"
        case .infrared: return "Thermal"
        case .custom: return "Custom"
        }
    }

    var description: String {
        switch self {
        case .tactical: return "Classic green tactical HUD"
        case .night: return "Blue night vision mode"
        case .infrared: return "Orange thermal imaging"
        case .custom: return "Define primary, secondary, and accent hex colors"
        }
    }
}

struct ThemePalette {
    let primary: Color
    let secondary: Color
    let accent: Color
    let background: Color
    let surface: Color
    let text: Color
    let success: Color
    let warning: Color
    let error: Color

    static func makeDefault(primary: Color, secondary: Color, accent: Color) -> ThemePalette {
        ThemePalette(
            primary: primary,
            secondary: secondary,
            accent: accent,
            background: Color.black,
            surface: Color(red: 0.05, green: 0.05, blue: 0.05),
            text: primary,
            success: accent,
            warning: Color(red: 1.0, green: 0.8, blue: 0.0),
            error: Color(red: 1.0, green: 0.2, blue: 0.2)
        )
    }
}

struct CustomThemePalette: Equatable, Codable {
    var primaryHex: String
    var secondaryHex: String
    var accentHex: String

    init(primaryHex: String = "#00F900", secondaryHex: String = "#005B2A", accentHex: String = "#3AFF74") {
        self.primaryHex = primaryHex
        self.secondaryHex = secondaryHex
        self.accentHex = accentHex
    }

    var primaryColor: Color { Color(hex: primaryHex) ?? Color(red: 0.0, green: 0.8, blue: 0.0) }
    var secondaryColor: Color { Color(hex: secondaryHex) ?? Color(red: 0.0, green: 0.4, blue: 0.0) }
    var accentColor: Color { Color(hex: accentHex) ?? Color(red: 0.2, green: 1.0, blue: 0.2) }
}

extension Color {
    init?(hex: String) {
        var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        if cleaned.hasPrefix("#") {
            cleaned.removeFirst()
        }

        guard cleaned.count == 6 || cleaned.count == 8,
              let value = UInt64(cleaned, radix: 16) else {
            return nil
        }

        let r, g, b, a: Double

        if cleaned.count == 6 {
            r = Double((value & 0xFF0000) >> 16) / 255.0
            g = Double((value & 0x00FF00) >> 8) / 255.0
            b = Double(value & 0x0000FF) / 255.0
            a = 1.0
        } else {
            r = Double((value & 0xFF000000) >> 24) / 255.0
            g = Double((value & 0x00FF0000) >> 16) / 255.0
            b = Double((value & 0x0000FF00) >> 8) / 255.0
            a = Double(value & 0x000000FF) / 255.0
        }

        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}
