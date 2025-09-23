import SwiftUI

struct RecordingRow: View {
    let recording: VoiceRecording
    let viewModel: AudioViewModel
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var isEditing = false
    @State private var editingDescription = ""

    var body: some View {
        HUDPanel(title: "RECORDING") {
            HStack(spacing: 12) {
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
                        let isThisRecordingPlaying = viewModel.isPlayingRecording && viewModel.currentPlayingRecording?.id == recording.id
                        let _ = print("🔍 RecordingRow debug - Recording: \(recording.id), isPlayingRecording: \(viewModel.isPlayingRecording), currentPlayingRecording: \(viewModel.currentPlayingRecording?.id ?? UUID()), isThisRecordingPlaying: \(isThisRecordingPlaying)")

                        HStack(spacing: 8) {
                            if isThisRecordingPlaying {
                                CodecButton(title: "STOP", action: {
                                    TacticalSoundPlayer.playAction()
                                    viewModel.stopRecordingPlayback()
                                }, style: .primary, size: .small)
                            } else {
                                CodecButton(title: "PLAY", action: {
                                    TacticalSoundPlayer.playAction()
                                    viewModel.playRecording(recording)
                                }, style: .secondary, size: .small)
                            }

                            CodecButton(title: "DEL", action: {
                                TacticalSoundPlayer.playNavigation()
                                viewModel.deleteRecording(recording)
                            }, style: .destructive, size: .small)
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
}