import SwiftUI

struct CameraView: View {
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        ZStack {
            themeManager.backgroundColor
                .ignoresSafeArea()

            VStack {
                Text("CAMERA MODULE")
                    .font(.system(size: 16, design: .monospaced))
                    .foregroundColor(themeManager.primaryColor)

                Text("Initializing...")
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