import SwiftUI
import AVFoundation
import MediaPlayer
import Combine

@MainActor
class AudioViewModel: NSObject, ObservableObject {
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
    private var radioPlayer: AVPlayer?
    private var audioEngine = AVAudioEngine()
    private var inputNode: AVAudioInputNode?
    private var audioRecorder: AVAudioRecorder?
    private var recordingTimer: Timer?
    private var recordingStartTime: Date?
    private var audioLevelTimer: Timer?
    private var playerObserver: Any?
    private var cancellables = Set<AnyCancellable>()

    private let radioStations: [RadioStation] = [
        RadioStation(id: UUID(), name: "80S HITS", url: "https://streams.80s80s.de/web/mp3-192/streams.80s80s.de/", frequency: "80.5"),
        RadioStation(id: UUID(), name: "FLASHBACK", url: "https://streams.fluxfm.de/80er/mp3-320/audio/", frequency: "81.2")
    ]

    private var currentStationIndex = 0

    override init() {
        super.init()
        setupAudio()
        loadRecordings()
        currentStation = radioStations.first
        setupVolumeObserver()
    }

    deinit {
        // Clean up resources synchronously in deinit
        radioPlayer?.pause()
        radioPlayer = nil
        playerObserver = nil

        audioRecorder?.stop()
        audioRecorder = nil

        recordingTimer?.invalidate()
        recordingTimer = nil

        audioLevelTimer?.invalidate()
        audioLevelTimer = nil
    }

    private func setupVolumeObserver() {
        $volume
            .sink { [weak self] newVolume in
                self?.radioPlayer?.volume = Float(newVolume)
            }
            .store(in: &cancellables)
    }

    func handleError(_ error: Error) {
        print("AudioViewModel error: \(error.localizedDescription)")
    }

    private func setupAudio() {
        do {
            // Configure audio session for streaming and recording
            let session = AVAudioSession.sharedInstance()

            // Use playback category for better streaming performance when not recording
            if !isRecording {
                try session.setCategory(.playback, mode: .default, options: [.allowBluetoothHFP, .allowAirPlay])
            } else {
                try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothHFP, .allowAirPlay])
            }

            try session.setActive(true)
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

        print("🔊 Starting radio playback for: \(station.name) at \(station.url)")
        currentlyPlaying = "CONNECTING..."
        signalStrength = 1

        // Create AVPlayer for streaming
        radioPlayer = AVPlayer(url: url)
        radioPlayer?.volume = Float(volume)

        // Observe player status
        playerObserver = radioPlayer?.observe(\.status, options: [.new]) { [weak self] player, _ in
            DispatchQueue.main.async {
                switch player.status {
                case .readyToPlay:
                    self?.isPlaying = true
                    self?.currentlyPlaying = "STREAMING: \(station.name)"
                    self?.signalStrength = 4
                    player.play()
                case .failed:
                    print("🔊 Radio player failed with error: \(player.error?.localizedDescription ?? "Unknown error")")
                    self?.handleRadioError(player.error)
                case .unknown:
                    self?.currentlyPlaying = "BUFFERING..."
                    self?.signalStrength = 2
                @unknown default:
                    break
                }
            }
        }

        // Start playback
        radioPlayer?.play()

        // Simulate track info updates (since most streams don't provide metadata easily)
        Timer.scheduledTimer(withTimeInterval: 45.0, repeats: true) { _ in
            Task { @MainActor in
                if self.isPlaying {
                    self.simulateTrackChange()
                }
            }
        }
    }

    private func handleRadioError(_ error: Error?) {
        isPlaying = false
        currentlyPlaying = "SIGNAL LOST"
        signalStrength = 0
        if let error = error {
            print("Radio stream error: \(error.localizedDescription)")
        }

        // Try to switch to next station automatically after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if !self.isPlaying && self.currentStation != nil {
                print("Auto-switching to next station due to connection failure")
                self.nextStation()
            }
        }
    }

    private func stopRadio() {
        radioPlayer?.pause()
        radioPlayer = nil

        // Remove observer
        if playerObserver != nil {
            // Note: KVO observer will be automatically removed when radioPlayer is deallocated
            playerObserver = nil
        }

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
        let wasPlaying = isPlaying
        stopRadio()

        currentStationIndex = (currentStationIndex + 1) % radioStations.count
        currentStation = radioStations[currentStationIndex]

        if wasPlaying {
            playRadio()
        }
    }

    func previousStation() {
        let wasPlaying = isPlaying
        stopRadio()

        currentStationIndex = currentStationIndex > 0 ? currentStationIndex - 1 : radioStations.count - 1
        currentStation = radioStations[currentStationIndex]

        if wasPlaying {
            playRadio()
        }
    }

    func requestMicrophonePermission() {
        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission { granted in
                DispatchQueue.main.async {
                    if !granted {
                        self.recordingStatus = "MIC ACCESS DENIED"
                    }
                }
            }
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                DispatchQueue.main.async {
                    if !granted {
                        self.recordingStatus = "MIC ACCESS DENIED"
                    }
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
        let hasPermission: Bool
        if #available(iOS 17.0, *) {
            hasPermission = AVAudioApplication.shared.recordPermission == .granted
        } else {
            hasPermission = AVAudioSession.sharedInstance().recordPermission == .granted
        }

        guard hasPermission else {
            recordingStatus = "PERMISSION REQUIRED"
            return
        }

        // Reconfigure audio session for recording
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothHFP])
            try session.setActive(true)
        } catch {
            handleError(error)
            recordingStatus = "AUDIO SESSION ERROR"
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

        // Reconfigure audio session back to playback mode
        setupAudio()

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