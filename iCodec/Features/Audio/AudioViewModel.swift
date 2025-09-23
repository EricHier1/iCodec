import SwiftUI
import AVFoundation
import MediaPlayer
import Combine

@MainActor
class AudioViewModel: BaseViewModel {
    @Published var isPlaying = false
    @Published var volume: Double = 0.5
    @Published var currentStation: RadioStation?
    @Published var currentlyPlaying = "NO SIGNAL"
    @Published var signalStrength = 0
    @Published var isRecording = false
    @Published var recordingStatus = "READY"
    @Published var recordingDuration = "00:00"
    @Published var recordingPulse = false
    @Published var audioLevel: Float = 0.0
    @Published var recordings: [VoiceRecording] = []
    @Published var hasRecordings = false

    private var audioPlayer: AVAudioPlayer?
    private var audioEngine = AVAudioEngine()
    private var inputNode: AVAudioInputNode?
    private var audioRecorder: AVAudioRecorder?
    private var recordingTimer: Timer?
    private var recordingStartTime: Date?
    private var audioLevelTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    private let radioStations: [RadioStation] = [
        RadioStation(id: UUID(), name: "RETRO FM", url: "https://stream.radioparadise.com/rock-320", frequency: "80.5"),
        RadioStation(id: UUID(), name: "80S HITS", url: "https://streaming.live365.com/a16077", frequency: "81.2"),
        RadioStation(id: UUID(), name: "NEON RADIO", url: "https://streamingp.shoutcast.com/80s-aac", frequency: "82.7"),
        RadioStation(id: UUID(), name: "FLASHBACK", url: "https://edge.audioxi.com/80S", frequency: "83.1")
    ]

    private var currentStationIndex = 0

    override init() {
        super.init()
        setupAudio()
        loadRecordings()
        currentStation = radioStations.first
    }

    private func setupAudio() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            handleError(error)
        }
    }

    func toggleRadio() {
        if isPlaying {
            stopRadio()
        } else {
            playRadio()
        }
    }

    private func playRadio() {
        guard let station = currentStation,
              let url = URL(string: station.url) else { return }

        Task {
            do {
                // Simulate loading
                currentlyPlaying = "CONNECTING..."
                signalStrength = 1

                // In a real implementation, use AVPlayer for streaming
                // For demo purposes, we'll simulate playback
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

                await MainActor.run {
                    isPlaying = true
                    currentlyPlaying = "NOW PLAYING: Take On Me - a-ha"
                    signalStrength = 4

                    // Simulate changing tracks
                    Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
                        Task { @MainActor in
                            self.simulateTrackChange()
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    handleError(error)
                    currentlyPlaying = "CONNECTION FAILED"
                    signalStrength = 0
                }
            }
        }
    }

    private func stopRadio() {
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
        currentlyPlaying = "STANDBY"
        signalStrength = 0
    }

    private func simulateTrackChange() {
        let tracks = [
            "Take On Me - a-ha",
            "Sweet Dreams - Eurythmics",
            "Billie Jean - Michael Jackson",
            "Don't Stop Believin' - Journey",
            "Girls Just Want to Have Fun - Cyndi Lauper",
            "Flashdance - Irene Cara",
            "Eye of the Tiger - Survivor",
            "Total Eclipse of the Heart - Bonnie Tyler"
        ]
        currentlyPlaying = "NOW PLAYING: \(tracks.randomElement() ?? "Unknown Track")"
    }

    func nextStation() {
        currentStationIndex = (currentStationIndex + 1) % radioStations.count
        currentStation = radioStations[currentStationIndex]

        if isPlaying {
            stopRadio()
            playRadio()
        }
    }

    func previousStation() {
        currentStationIndex = currentStationIndex > 0 ? currentStationIndex - 1 : radioStations.count - 1
        currentStation = radioStations[currentStationIndex]

        if isPlaying {
            stopRadio()
            playRadio()
        }
    }

    func requestMicrophonePermission() {
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            DispatchQueue.main.async {
                if !granted {
                    self.recordingStatus = "MIC ACCESS DENIED"
                }
            }
        }
    }

    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        guard AVAudioSession.sharedInstance().recordPermission == .granted else {
            recordingStatus = "PERMISSION REQUIRED"
            return
        }

        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioFilename = documentsPath.appendingPathComponent("recording_\(Date().timeIntervalSince1970).m4a")

        let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 12000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()

            isRecording = true
            recordingStatus = "RECORDING"
            recordingStartTime = Date()

            // Start timers
            startRecordingTimer()
            startAudioLevelMonitoring()

        } catch {
            handleError(error)
            recordingStatus = "RECORDING FAILED"
        }
    }

    private func stopRecording() {
        audioRecorder?.stop()
        audioRecorder = nil

        isRecording = false
        recordingStatus = "READY"
        recordingDuration = "00:00"
        audioLevel = 0.0

        stopRecordingTimer()
        stopAudioLevelMonitoring()

        // Reload recordings
        loadRecordings()
    }

    private func startRecordingTimer() {
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                self.updateRecordingDuration()
                self.recordingPulse.toggle()
            }
        }
    }

    private func stopRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        recordingPulse = false
    }

    private func updateRecordingDuration() {
        guard let startTime = recordingStartTime else { return }
        let duration = Date().timeIntervalSince(startTime)
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        recordingDuration = String(format: "%02d:%02d", minutes, seconds)
    }

    private func startAudioLevelMonitoring() {
        audioLevelTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            Task { @MainActor in
                self.updateAudioLevel()
            }
        }
    }

    private func stopAudioLevelMonitoring() {
        audioLevelTimer?.invalidate()
        audioLevelTimer = nil
    }

    private func updateAudioLevel() {
        audioRecorder?.updateMeters()
        let level = audioRecorder?.averagePower(forChannel: 0) ?? -160
        // Convert from decibels to 0-1 range
        let normalizedLevel = pow(10, level / 20)
        audioLevel = Float(max(0, min(1, normalizedLevel * 10)))
    }

    func playLastRecording() {
        guard let lastRecording = recordings.first else { return }
        playRecording(lastRecording)
    }

    func playRecording(_ recording: VoiceRecording) {
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: recording.url)
            audioPlayer?.volume = Float(volume)
            audioPlayer?.play()
        } catch {
            handleError(error)
        }
    }

    func deleteRecording(_ recording: VoiceRecording) {
        do {
            try FileManager.default.removeItem(at: recording.url)
            loadRecordings()
        } catch {
            handleError(error)
        }
    }

    private func loadRecordings() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]

        do {
            let files = try FileManager.default.contentsOfDirectory(at: documentsPath, includingPropertiesForKeys: [.creationDateKey], options: [])

            recordings = files
                .filter { $0.pathExtension == "m4a" && $0.lastPathComponent.hasPrefix("recording_") }
                .compactMap { url -> VoiceRecording? in
                    guard let creationDate = try? url.resourceValues(forKeys: [.creationDateKey]).creationDate else {
                        return nil
                    }
                    return VoiceRecording(id: UUID(), url: url, date: creationDate)
                }
                .sorted { $0.date > $1.date }

            hasRecordings = !recordings.isEmpty

        } catch {
            recordings = []
            hasRecordings = false
        }
    }
}

extension AudioViewModel: AVAudioRecorderDelegate {
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in
            if flag {
                loadRecordings()
            } else {
                recordingStatus = "RECORDING FAILED"
            }
        }
    }
}

struct RadioStation: Identifiable {
    let id: UUID
    let name: String
    let url: String
    let frequency: String
}

struct VoiceRecording: Identifiable {
    let id: UUID
    let url: URL
    let date: Date

    var duration: String {
        do {
            let audioPlayer = try AVAudioPlayer(contentsOf: url)
            let duration = audioPlayer.duration
            let minutes = Int(duration) / 60
            let seconds = Int(duration) % 60
            return String(format: "%02d:%02d", minutes, seconds)
        } catch {
            return "00:00"
        }
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM dd, HH:mm"
        return formatter.string(from: date)
    }
}