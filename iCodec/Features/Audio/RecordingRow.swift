import SwiftUI

struct RecordingRow: View {
    let recording: VoiceRecording
    let viewModel: AudioViewModel
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var isEditing = false
    @State private var editingDescription = ""
    @State private var pulseAnimation = false

    var body: some View {
        let isThisRecordingPlaying = viewModel.isPlayingRecording && viewModel.currentPlayingRecording?.id == recording.id
        let _ = print("🎵 RecordingRow body update - Recording: \(recording.id.uuidString.prefix(8)), isPlayingRecording: \(viewModel.isPlayingRecording), currentPlaying: \(viewModel.currentPlayingRecording?.id.uuidString.prefix(8) ?? "none"), isThisRecordingPlaying: \(isThisRecordingPlaying)")

        HUDPanel(title: isThisRecordingPlaying ? "PLAYING" : "RECORDING") {
            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    // Playback indicator icon
                    ZStack {
                        Circle()
                            .fill(isThisRecordingPlaying ? themeManager.primaryColor.opacity(0.2) : themeManager.surfaceColor.opacity(0.3))
                            .frame(width: 40, height: 40)

                        Image(systemName: isThisRecordingPlaying ? "waveform" : "mic.fill")
                            .font(.system(size: 18))
                            .foregroundColor(isThisRecordingPlaying ? themeManager.primaryColor : themeManager.textColor.opacity(0.7))
                            .scaleEffect(isThisRecordingPlaying && pulseAnimation ? 1.1 : 1.0)
                            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulseAnimation)
                    }

                    // Recording info
                    VStack(alignment: .leading, spacing: 4) {
                    if isEditing {
                        TextField("Recording description", text: $editingDescription)
                            .textFieldStyle(PlainTextFieldStyle())
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(themeManager.primaryColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(themeManager.surfaceColor.opacity(0.3))
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(themeManager.primaryColor.opacity(0.5), lineWidth: 1)
                            )
                    } else {
                        HStack {
                            Text(recording.displayName)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(themeManager.primaryColor)
                                .fontWeight(.bold)

                            Button(action: {
                                editingDescription = recording.description
                                isEditing = true
                            }) {
                                Text("EDIT")
                                    .font(.system(size: 8, design: .monospaced))
                                    .foregroundColor(themeManager.accentColor)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(themeManager.accentColor.opacity(0.2))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 2)
                                            .stroke(themeManager.accentColor, lineWidth: 1)
                                    )
                            }
                        }
                    }

                    Text(recording.formattedDate)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(themeManager.textColor.opacity(0.7))

                    Text("Duration: \(recording.duration)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(themeManager.textColor.opacity(0.7))
                }

                    Spacer()

                    // Controls
                    VStack(spacing: 4) {
                        if isEditing {
                            HStack(spacing: 4) {
                                CodecButton(title: "SAVE", action: {
                                    TacticalSoundPlayer.playAction()
                                    viewModel.updateRecordingDescription(recording, description: editingDescription)
                                    isEditing = false
                                }, style: .primary, size: .small)

                                CodecButton(title: "CANCEL", action: {
                                    TacticalSoundPlayer.playNavigation()
                                    isEditing = false
                                }, style: .secondary, size: .small)
                            }
                        } else {
                            VStack(spacing: 6) {
                                // Main playback controls
                                HStack(spacing: 8) {
                                    if isThisRecordingPlaying {
                                        CodecButton(title: "⏸ STOP", action: {
                                            TacticalSoundPlayer.playAction()
                                            viewModel.stopRecordingPlayback()
                                        }, style: .primary, size: .small)
                                    } else {
                                        CodecButton(title: "▶ PLAY", action: {
                                            TacticalSoundPlayer.playAction()
                                            viewModel.playRecording(recording)
                                        }, style: .secondary, size: .small)
                                    }

                                    Button(action: {
                                        shareRecording()
                                    }) {
                                        Image(systemName: "square.and.arrow.up")
                                            .font(.system(size: 12))
                                            .foregroundColor(themeManager.accentColor)
                                            .frame(width: 32, height: 32)
                                            .background(themeManager.accentColor.opacity(0.2))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 4)
                                                    .stroke(themeManager.accentColor, lineWidth: 1)
                                            )
                                            .cornerRadius(4)
                                    }

                                    Button(action: {
                                        TacticalSoundPlayer.playNavigation()
                                        viewModel.deleteRecording(recording)
                                    }) {
                                        Image(systemName: "trash")
                                            .font(.system(size: 12))
                                            .foregroundColor(themeManager.errorColor)
                                            .frame(width: 32, height: 32)
                                            .background(themeManager.errorColor.opacity(0.2))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 4)
                                                    .stroke(themeManager.errorColor, lineWidth: 1)
                                            )
                                            .cornerRadius(4)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 4)

                // Visual playback indicator bar when playing
                if isThisRecordingPlaying {
                    VStack(spacing: 4) {
                        HStack(spacing: 2) {
                            ForEach(0..<30, id: \.self) { index in
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(themeManager.primaryColor.opacity(0.6))
                                    .frame(width: 3, height: CGFloat.random(in: 4...12))
                                    .animation(.easeInOut(duration: 0.3).repeatForever(autoreverses: true).delay(Double(index) * 0.02), value: pulseAnimation)
                            }
                        }
                        .frame(height: 12)
                        .padding(.horizontal, 8)
                    }
                }
            }
        }
        .onAppear {
            if isThisRecordingPlaying {
                pulseAnimation = true
            }
        }
        .onChange(of: isThisRecordingPlaying) { oldValue, newValue in
            pulseAnimation = newValue
        }
    }

    private func shareRecording() {
        let activityVC = UIActivityViewController(
            activityItems: [recording.url],
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {

            // For iPad - set popover presentation
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = window
                popover.sourceRect = CGRect(x: window.bounds.midX, y: window.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }

            rootVC.present(activityVC, animated: true)
        }
    }
}