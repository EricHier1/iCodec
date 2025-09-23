import SwiftUI

struct RecordingRow: View {
    let recording: VoiceRecording
    let viewModel: AudioViewModel
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        HUDPanel(title: "RECORDING") {
            HStack(spacing: 12) {
                // Recording info
                VStack(alignment: .leading, spacing: 4) {
                    Text("REC_\(recording.date.timeIntervalSince1970, specifier: "%.0f")")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(themeManager.primaryColor)
                        .fontWeight(.bold)

                    Text(recording.formattedDate)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(themeManager.textColor.opacity(0.7))

                    Text("Duration: \(recording.duration)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(themeManager.textColor.opacity(0.7))
                }

                Spacer()

                // Controls
                HStack(spacing: 8) {
                    CodecButton(title: "PLAY", action: {
                        TacticalSoundPlayer.playAction()
                        viewModel.playRecording(recording)
                    }, style: .secondary, size: .small)

                    CodecButton(title: "DEL", action: {
                        TacticalSoundPlayer.playNavigation()
                        viewModel.deleteRecording(recording)
                    }, style: .destructive, size: .small)
                }
            }
            .padding(.vertical, 4)
        }
    }
}