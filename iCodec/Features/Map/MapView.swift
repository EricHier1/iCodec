import SwiftUI

struct MapView: View {
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        ZStack {
            themeManager.backgroundColor
                .ignoresSafeArea()

            VStack {
                Text("TACTICAL MAP")
                    .font(.system(size: 16, design: .monospaced))
                    .foregroundColor(themeManager.primaryColor)

                Text("Loading terrain data...")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(themeManager.textColor.opacity(0.7))
            }
        }
        .overlay(
            ScanlineOverlay()
                .opacity(0.1)
        )
    }
}