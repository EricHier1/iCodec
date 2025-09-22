import SwiftUI

struct CodecButton: View {
    let title: String
    let action: () -> Void
    var style: ButtonStyle = .primary
    var size: ButtonSize = .medium
    var isLoading: Bool = false

    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        Button(action: action) {
            HStack {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(textColor)
                } else {
                    Text(title)
                        .font(buttonFont)
                        .fontWeight(.semibold)
                }
            }
            .frame(height: buttonHeight)
            .frame(maxWidth: size == .fullWidth ? .infinity : nil)
            .padding(.horizontal, horizontalPadding)
            .foregroundColor(textColor)
            .background(backgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(borderColor, lineWidth: 1)
            )
            .overlay(
                ScanlineOverlay()
                    .opacity(0.3)
            )
        }
        .disabled(isLoading)
        .scaleEffect(isLoading ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isLoading)
    }

    private var backgroundColor: Color {
        switch style {
        case .primary: return themeManager.primaryColor.opacity(0.2)
        case .secondary: return themeManager.secondaryColor.opacity(0.2)
        case .destructive: return themeManager.errorColor.opacity(0.2)
        }
    }

    private var borderColor: Color {
        switch style {
        case .primary: return themeManager.primaryColor
        case .secondary: return themeManager.secondaryColor
        case .destructive: return themeManager.errorColor
        }
    }

    private var textColor: Color {
        switch style {
        case .primary: return themeManager.primaryColor
        case .secondary: return themeManager.secondaryColor
        case .destructive: return themeManager.errorColor
        }
    }

    private var buttonFont: Font {
        switch size {
        case .small: return .system(size: 12, design: .monospaced)
        case .medium: return .system(size: 14, design: .monospaced)
        case .large: return .system(size: 16, design: .monospaced)
        case .fullWidth: return .system(size: 14, design: .monospaced)
        }
    }

    private var buttonHeight: CGFloat {
        switch size {
        case .small: return 32
        case .medium: return 40
        case .large: return 48
        case .fullWidth: return 44
        }
    }

    private var horizontalPadding: CGFloat {
        switch size {
        case .small: return 12
        case .medium: return 16
        case .large: return 20
        case .fullWidth: return 20
        }
    }

    enum ButtonStyle {
        case primary, secondary, destructive
    }

    enum ButtonSize {
        case small, medium, large, fullWidth
    }
}

struct ScanlineOverlay: View {
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let lineSpacing: CGFloat = 4
                let lineCount = Int(geometry.size.height / lineSpacing)

                for i in 0..<lineCount {
                    let y = CGFloat(i) * lineSpacing
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                }
            }
            .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
        }
    }
}