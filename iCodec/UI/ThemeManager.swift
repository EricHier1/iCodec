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

    var primaryColor: Color {
        switch self {
        case .tactical: return Color(red: 0.0, green: 0.8, blue: 0.0)
        case .night: return Color(red: 0.0, green: 0.6, blue: 0.8)
        case .infrared: return Color(red: 1.0, green: 0.4, blue: 0.0)
        }
    }

    var secondaryColor: Color {
        switch self {
        case .tactical: return Color(red: 0.0, green: 0.4, blue: 0.0)
        case .night: return Color(red: 0.0, green: 0.3, blue: 0.4)
        case .infrared: return Color(red: 0.6, green: 0.2, blue: 0.0)
        }
    }

    var accentColor: Color {
        switch self {
        case .tactical: return Color(red: 0.2, green: 1.0, blue: 0.2)
        case .night: return Color(red: 0.2, green: 0.8, blue: 1.0)
        case .infrared: return Color(red: 1.0, green: 0.6, blue: 0.2)
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
        Color(red: 0.0, green: 0.8, blue: 0.0)
    }

    var warningColor: Color {
        Color(red: 1.0, green: 0.8, blue: 0.0)
    }

    var errorColor: Color {
        Color(red: 1.0, green: 0.2, blue: 0.2)
    }

    var name: String {
        switch self {
        case .tactical: return "Tactical"
        case .night: return "Night Vision"
        case .infrared: return "Thermal"
        }
    }
}