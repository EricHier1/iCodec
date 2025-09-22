import SwiftUI

struct AudioView: View {
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        ZStack {
            themeManager.backgroundColor
                .ignoresSafeArea()

            VStack {
                Text("AUDIO CODEC")
                    .font(.system(size: 16, family: .monospaced))
                    .foregroundColor(themeManager.primaryColor)

                Text("Frequency calibrating...")
                    .font(.system(size: 12, family: .monospaced))
                    .foregroundColor(themeManager.textColor.opacity(0.7))
            }
        }
        .overlay(
            ScanlineOverlay()
                .opacity(0.1)
        )
    }
}