import SwiftUI
import Combine

@MainActor
class ThemeManager: ObservableObject {
    @Published var currentTheme: CodecTheme = .tactical

    var primaryColor: Color { currentTheme.primaryColor }
    var secondaryColor: Color { currentTheme.secondaryColor }
    var accentColor: Color { currentTheme.accentColor }
    var backgroundColor: Color { currentTheme.backgroundColor }
    var surfaceColor: Color { currentTheme.surfaceColor }
    var textColor: Color { currentTheme.textColor }
    var successColor: Color { currentTheme.successColor }
    var warningColor: Color { currentTheme.warningColor }
    var errorColor: Color { currentTheme.errorColor }

    func switchTheme(to theme: CodecTheme) {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentTheme = theme
        }
    }
}

enum CodecTheme: CaseIterable {
    case tactical
    case night
    case infrared
    case arctic
    case sunset
    case purple

    var primaryColor: Color {
        switch self {
        case .tactical: return Color(red: 0.0, green: 0.8, blue: 0.0)  // Green
        case .night: return Color(red: 0.0, green: 0.6, blue: 0.8)     // Blue
        case .infrared: return Color(red: 1.0, green: 0.4, blue: 0.0)  // Orange
        case .arctic: return Color(red: 0.0, green: 0.8, blue: 0.9)    // Cyan
        case .sunset: return Color(red: 1.0, green: 0.6, blue: 0.8)    // Pink
        case .purple: return Color(red: 0.7, green: 0.3, blue: 1.0)    // Purple
        }
    }

    var secondaryColor: Color {
        switch self {
        case .tactical: return Color(red: 0.0, green: 0.4, blue: 0.0)   // Dark Green
        case .night: return Color(red: 0.0, green: 0.3, blue: 0.4)      // Dark Blue
        case .infrared: return Color(red: 0.6, green: 0.2, blue: 0.0)   // Dark Orange
        case .arctic: return Color(red: 0.0, green: 0.4, blue: 0.5)     // Dark Cyan
        case .sunset: return Color(red: 0.6, green: 0.3, blue: 0.4)     // Dark Pink
        case .purple: return Color(red: 0.4, green: 0.2, blue: 0.6)     // Dark Purple
        }
    }

    var accentColor: Color {
        switch self {
        case .tactical: return Color(red: 0.2, green: 1.0, blue: 0.2)   // Bright Green
        case .night: return Color(red: 0.2, green: 0.8, blue: 1.0)      // Bright Blue
        case .infrared: return Color(red: 1.0, green: 0.6, blue: 0.2)   // Bright Orange
        case .arctic: return Color(red: 0.3, green: 1.0, blue: 1.0)     // Bright Cyan
        case .sunset: return Color(red: 1.0, green: 0.8, blue: 0.9)     // Bright Pink
        case .purple: return Color(red: 0.9, green: 0.5, blue: 1.0)     // Bright Purple
        }
    }

    var backgroundColor: Color {
        Color.black
    }

    var surfaceColor: Color {
        Color(red: 0.05, green: 0.05, blue: 0.05)
    }

    var textColor: Color {
        primaryColor
    }

    var successColor: Color {
        switch self {
        case .tactical: return Color(red: 0.0, green: 0.8, blue: 0.0)   // Green
        case .night: return Color(red: 0.2, green: 0.8, blue: 1.0)      // Blue
        case .infrared: return Color(red: 1.0, green: 0.6, blue: 0.2)   // Orange
        case .arctic: return Color(red: 0.3, green: 1.0, blue: 1.0)     // Cyan
        case .sunset: return Color(red: 1.0, green: 0.8, blue: 0.9)     // Pink
        case .purple: return Color(red: 0.9, green: 0.5, blue: 1.0)     // Purple
        }
    }

    var warningColor: Color {
        Color(red: 1.0, green: 0.8, blue: 0.0)  // Universal warning yellow
    }

    var errorColor: Color {
        Color(red: 1.0, green: 0.2, blue: 0.2)  // Universal error red
    }

    var name: String {
        switch self {
        case .tactical: return "Tactical"
        case .night: return "Night Vision"
        case .infrared: return "Thermal"
        case .arctic: return "Arctic"
        case .sunset: return "Sunset"
        case .purple: return "Phantom"
        }
    }

    var description: String {
        switch self {
        case .tactical: return "Classic green tactical HUD"
        case .night: return "Blue night vision mode"
        case .infrared: return "Orange thermal imaging"
        case .arctic: return "Cyan cold weather ops"
        case .sunset: return "Pink/magenta aesthetic"
        case .purple: return "Purple stealth mode"
        }
    }
}