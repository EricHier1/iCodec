import SwiftUI

struct HUDPanel<Content: View>: View {
    let title: String
    let content: Content
    var showBorder: Bool = true

    @EnvironmentObject private var themeManager: ThemeManager

    init(title: String, showBorder: Bool = true, @ViewBuilder content: () -> Content) {
        self.title = title
        self.showBorder = showBorder
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(themeManager.primaryColor)
                    .textCase(.uppercase)

                Spacer()

                HStack(spacing: 4) {
                    Circle()
                        .fill(themeManager.successColor)
                        .frame(width: 6, height: 6)
                        .opacity(0.8)

                    Text("ONLINE")
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(themeManager.successColor)
                }
            }

            content
                .padding(12)
                .background(themeManager.surfaceColor.opacity(0.3))
                .overlay(
                    ScanlineOverlay()
                        .opacity(0.2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(
                            showBorder ? themeManager.primaryColor.opacity(0.5) : Color.clear,
                            lineWidth: 1
                        )
                )
        }
        .padding(.horizontal, 16)
    }
}

struct RadarSweep: View {
    @State private var rotationAngle: Double = 0
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        ZStack {
            Circle()
                .stroke(themeManager.primaryColor.opacity(0.3), lineWidth: 1)

            Circle()
                .stroke(themeManager.primaryColor.opacity(0.2), lineWidth: 1)
                .scaleEffect(0.7)

            Circle()
                .stroke(themeManager.primaryColor.opacity(0.1), lineWidth: 1)
                .scaleEffect(0.4)

            Path { path in
                path.move(to: CGPoint(x: 50, y: 50))
                path.addLine(to: CGPoint(x: 50, y: 0))
            }
            .stroke(
                LinearGradient(
                    gradient: Gradient(colors: [
                        themeManager.primaryColor.opacity(0.8),
                        themeManager.primaryColor.opacity(0)
                    ]),
                    startPoint: .center,
                    endPoint: .top
                ),
                lineWidth: 2
            )
            .rotationEffect(.degrees(rotationAngle))

            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(themeManager.accentColor)
                    .frame(width: 3, height: 3)
                    .offset(x: CGFloat.random(in: -30...30), y: CGFloat.random(in: -30...30))
                    .opacity(0.6)
            }
        }
        .frame(width: 100, height: 100)
        .onAppear {
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                rotationAngle = 360
            }
        }
    }
}