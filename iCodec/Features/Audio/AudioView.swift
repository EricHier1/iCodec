import SwiftUI
import AVFoundation

struct AudioView: View {
    @StateObject private var viewModel = AudioViewModel()
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("TACTICAL COMMS")
                    .font(.system(size: 16, design: .monospaced))
                    .foregroundColor(themeManager.primaryColor)
                    .fontWeight(.bold)

                Spacer()

                Text("COM")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(themeManager.accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(themeManager.accentColor.opacity(0.2))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(themeManager.accentColor, lineWidth: 1)
                    )
                    .cornerRadius(4)
            }
            .padding(.horizontal, 16)

            ScrollView {
                VStack(spacing: 20) {
                    // Radio Section
                    radioSection

                    // Custom Station Section
                    customStationSection

                    // Voice Recording Section
                    voiceRecordingSection

                    // Saved Recordings Section
                    savedRecordingsSection
                }
                .padding(.horizontal, 16)
            }
        }
        .background(themeManager.backgroundColor)
        .onAppear {
            viewModel.requestMicrophonePermission()
        }
        .onDisappear {
            // Don't stop radio when switching tabs, but ensure clean state
            if viewModel.isRecording {
                viewModel.toggleRecording()
            }
        }
    }

    private var radioSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("80'S HITS RADIO")
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(themeManager.accentColor)
                .fontWeight(.bold)

            HUDPanel(title: "Radio Control") {
                VStack(spacing: 16) {
                    // Station Display
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(viewModel.currentStation?.name ?? "NO SIGNAL")
                                .font(.system(size: 14, design: .monospaced))
                                .foregroundColor(themeManager.primaryColor)
                                .fontWeight(.bold)

                            Text(viewModel.currentlyPlaying)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(themeManager.textColor.opacity(0.8))
                                .lineLimit(2)
                        }

                        Spacer()

                        // Signal strength indicator
                        VStack(spacing: 2) {
                            ForEach(0..<5, id: \.self) { bar in
                                Rectangle()
                                    .fill(bar < viewModel.signalStrength ? themeManager.successColor : themeManager.surfaceColor)
                                    .frame(width: 4, height: CGFloat(4 + bar * 2))
                            }
                        }
                    }

                    // Controls
                    HStack(spacing: 16) {
                        CodecButton(title: "PREV", action: {
                            TacticalSoundPlayer.playNavigation()
                            viewModel.previousStation()
                        }, style: .secondary, size: .small)

                        Button(action: {
                            TacticalSoundPlayer.playAction()
                            viewModel.toggleRadio()
                        }) {
                            Text(viewModel.isPlaying ? "STOP" : "PLAY")
                                .font(.system(size: 14, design: .monospaced))
                                .fontWeight(.semibold)
                                .foregroundColor(themeManager.primaryColor)
                                .frame(width: 60, height: 40) // Fixed width to prevent resizing
                                .background(themeManager.primaryColor.opacity(0.2))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(themeManager.primaryColor, lineWidth: 1)
                                )
                                .overlay(
                                    ScanlineOverlay()
                                        .opacity(0.3)
                                )
                        }

                        CodecButton(title: "NEXT", action: {
                            TacticalSoundPlayer.playNavigation()
                            viewModel.nextStation()
                        }, style: .secondary, size: .small)

                        Spacer()

                        // Volume control
                        VStack(spacing: 4) {
                            Text("VOL")
                                .font(.system(size: 8, design: .monospaced))
                                .foregroundColor(themeManager.textColor.opacity(0.7))

                            Slider(value: $viewModel.volume, in: 0...1)
                                .frame(width: 80)
                                .tint(themeManager.primaryColor)
                        }
                    }
                }
            }
        }
    }

    private var voiceRecordingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("VOICE RECORDER")
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(themeManager.accentColor)
                .fontWeight(.bold)

            HUDPanel(title: "Recording Control") {
                VStack(spacing: 16) {
                    // Recording status
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(viewModel.recordingStatus)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(viewModel.isRecording ? themeManager.errorColor : themeManager.textColor)
                                .fontWeight(.bold)

                            if viewModel.isRecording {
                                Text("Duration: \(viewModel.recordingDuration)")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(themeManager.textColor.opacity(0.8))
                            }
                        }

                        Spacer()

                        // Recording indicator
                        if viewModel.isRecording {
                            Circle()
                                .fill(themeManager.errorColor)
                                .frame(width: 12, height: 12)
                                .scaleEffect(viewModel.recordingPulse ? 1.2 : 1.0)
                                .animation(.easeInOut(duration: 0.5).repeatForever(), value: viewModel.recordingPulse)
                        }
                    }

                    // Audio level meter
                    if viewModel.isRecording {
                        VStack(spacing: 4) {
                            Text("LEVEL")
                                .font(.system(size: 8, design: .monospaced))
                                .foregroundColor(themeManager.textColor.opacity(0.7))

                            GeometryReader { geometry in
                                HStack(spacing: 2) {
                                    ForEach(0..<20, id: \.self) { bar in
                                        Rectangle()
                                            .fill(bar < Int(viewModel.audioLevel * 20) ?
                                                (bar < 14 ? themeManager.successColor :
                                                 bar < 18 ? themeManager.warningColor : themeManager.errorColor) :
                                                themeManager.surfaceColor.opacity(0.3))
                                            .frame(width: (geometry.size.width - 38) / 20)
                                    }
                                }
                            }
                            .frame(height: 8)
                        }
                    }

                    // Controls
                    HStack(spacing: 16) {
                        Button(action: {
                            TacticalSoundPlayer.playAction()
                            viewModel.toggleRecording()
                        }) {
                            Text(viewModel.isRecording ? "STOP" : "REC")
                                .font(.system(size: 14, design: .monospaced))
                                .fontWeight(.semibold)
                                .foregroundColor(viewModel.isRecording ? themeManager.secondaryColor : themeManager.primaryColor)
                                .frame(width: 60, height: 40) // Fixed width to prevent resizing
                                .background((viewModel.isRecording ? themeManager.secondaryColor : themeManager.primaryColor).opacity(0.2))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(viewModel.isRecording ? themeManager.secondaryColor : themeManager.primaryColor, lineWidth: 1)
                                )
                                .overlay(
                                    ScanlineOverlay()
                                        .opacity(0.3)
                                )
                        }

                        if viewModel.hasRecordings {
                            CodecButton(title: "PLAY LAST", action: {
                                TacticalSoundPlayer.playNavigation()
                                viewModel.playLastRecording()
                            }, style: .secondary, size: .medium)
                        }

                        Spacer()
                    }
                }
            }
        }
    }

    private var customStationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CUSTOM STATIONS")
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(themeManager.accentColor)
                .fontWeight(.bold)

            HUDPanel(title: "Add Station") {
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("STATION NAME")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(themeManager.textColor.opacity(0.7))

                            TextField("", text: $viewModel.customStationName)
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
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("FREQUENCY")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(themeManager.textColor.opacity(0.7))

                            TextField("", text: $viewModel.customStationFrequency)
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
                                .frame(width: 80)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("STREAM URL")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(themeManager.textColor.opacity(0.7))

                        TextField("https://example.com/stream", text: $viewModel.customStationURL)
                            .textFieldStyle(PlainTextFieldStyle())
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(themeManager.primaryColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(themeManager.surfaceColor.opacity(0.3))
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(themeManager.primaryColor.opacity(0.5), lineWidth: 1)
                            )
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }

                    HStack {
                        CodecButton(
                            title: "ADD STATION",
                            action: {
                                TacticalSoundPlayer.playAction()
                                viewModel.addCustomStation()
                            },
                            style: .primary,
                            size: .medium
                        )
                        .disabled(viewModel.customStationName.isEmpty || viewModel.customStationURL.isEmpty)

                        Spacer()
                    }

                    if let error = viewModel.customStationError {
                        HStack {
                            Text(error)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.red)
                                .multilineTextAlignment(.leading)
                            Spacer()
                        }
                        .padding(.horizontal, 8)
                        .padding(.top, 4)
                    }
                }
            }

            // Custom stations list
            if !viewModel.customStations.isEmpty {
                VStack(spacing: 8) {
                    ForEach(viewModel.customStations) { station in
                        CustomStationRow(station: station, viewModel: viewModel)
                    }
                }
            }
        }
    }

    private var savedRecordingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("SAVED RECORDINGS")
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(themeManager.accentColor)
                    .fontWeight(.bold)

                Spacer()

                Text("\(viewModel.recordings.count) FILES")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(themeManager.textColor.opacity(0.7))
            }

            if viewModel.recordings.isEmpty {
                HUDPanel(title: "Storage") {
                    Text("No recordings stored")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(themeManager.textColor.opacity(0.7))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
            } else {
                VStack(spacing: 8) {
                    ForEach(viewModel.recordings) { recording in
                        RecordingRow(recording: recording, viewModel: viewModel)
                    }
                }
            }
        }
    }
}

struct CustomStationRow: View {
    let station: RadioStation
    let viewModel: AudioViewModel
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        HUDPanel(title: "Custom Station") {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(station.name)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(themeManager.primaryColor)
                        .fontWeight(.bold)

                    Text("FM \(station.frequency)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(themeManager.textColor.opacity(0.7))
                }

                Spacer()

                HStack(spacing: 8) {
                    CodecButton(
                        title: "PLAY",
                        action: {
                            TacticalSoundPlayer.playAction()
                            viewModel.playCustomStation(station)
                        },
                        style: .secondary,
                        size: .small
                    )

                    Button(action: {
                        TacticalSoundPlayer.playNavigation()
                        viewModel.deleteCustomStation(station)
                    }) {
                        Text("DEL")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(themeManager.errorColor)
                            .frame(width: 30, height: 24)
                            .background(themeManager.errorColor.opacity(0.2))
                            .overlay(
                                RoundedRectangle(cornerRadius: 2)
                                    .stroke(themeManager.errorColor, lineWidth: 1)
                            )
                    }
                }
            }
        }
    }
}