import SwiftUI
import AVFoundation
import MediaPlayer
import Combine
import Foundation

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
    @Published var isPlayingRecording = false
    @Published var currentPlayingRecording: VoiceRecording?
    @Published var customStations: [RadioStation] = []
    @Published var customStationName = ""
    @Published var customStationURL = ""
    @Published var customStationFrequency = ""
    @Published var customStationError: String?
    @Published var recordingName = ""
    fileprivate var currentRecordingName = ""
    @Published var spectrumLevels: [CGFloat] = Array(repeating: 0, count: 20)

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
    private var trackInfoTimer: Timer?
    private var spectrumTimer: Timer?
    nonisolated static func getCachedDuration(for url: URL) -> String? {
        return DurationCache.shared.getDuration(for: url)
    }

    nonisolated static func setCachedDuration(_ duration: String, for url: URL) {
        DurationCache.shared.setDuration(duration, for: url)
    }

    private let builtInStations: [RadioStation] = [
        RadioStation(id: UUID(), name: "80S HITS", url: "https://streams.80s80s.de/web/mp3-192/streams.80s80s.de/", frequency: "80.5"),
        RadioStation(id: UUID(), name: "FLASHBACK", url: "https://streams.fluxfm.de/80er/mp3-320/audio/", frequency: "81.2")
    ]

    private var radioStations: [RadioStation] {
        return builtInStations + customStations
    }

    private var currentStationIndex = 0

    private var audioDelegate: AudioDelegateHandler?

    override init() {
        super.init()
        audioDelegate = AudioDelegateHandler(viewModel: self)
        setupAudio()
        loadRecordings()
        loadCustomStations()
        currentStation = radioStations.first
        setupVolumeObserver()
    }

    deinit {
        print("🔊 AudioViewModel deinitializing")

        // Clean up observer safely
        if playerObserver != nil {
            // Note: The observer is a KVO observer, not a time observer
            // KVO observers are automatically cleaned up when the object is deallocated
            playerObserver = nil
        }

        // Clean up audio resources synchronously in deinit
        radioPlayer?.pause()
        radioPlayer?.replaceCurrentItem(with: nil)
        radioPlayer = nil

        audioRecorder?.stop()
        audioRecorder = nil

        recordingTimer?.invalidate()
        recordingTimer = nil

        audioLevelTimer?.invalidate()
        audioLevelTimer = nil

        trackInfoTimer?.invalidate()
        trackInfoTimer = nil

        // Cancel all Combine subscriptions
        cancellables.removeAll()

        // Remove notification observers
        NotificationCenter.default.removeObserver(self)
    }

    private func setupVolumeObserver() {
        $volume
            .sink { [weak self] newVolume in
                self?.radioPlayer?.volume = Float(newVolume)
            }
            .store(in: &cancellables)
    }

    override func handleError(_ error: Error) {
        super.handleError(error)
        print("AudioViewModel error: \(error.localizedDescription)")
    }

    private func setupAudio() {
        do {
            // Configure audio session for streaming and recording
            let session = AVAudioSession.sharedInstance()

            // Use playback category for better streaming performance when not recording
            if !isRecording {
                // Enable background audio playback
                // Note: For iOS 18+, .playback category doesn't support .allowBluetoothHFP
                // Use .allowBluetoothA2DP for Bluetooth audio output
                if #available(iOS 10.0, *) {
                    try session.setCategory(.playback, mode: .default, options: [.allowBluetoothA2DP, .allowAirPlay])
                } else {
                    try session.setCategory(.playback, mode: .default, options: .allowAirPlay)
                }
            } else {
                try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothHFP, .allowAirPlay])
            }

            try session.setActive(true)

            // Setup remote control commands for lock screen
            setupRemoteCommandCenter()

            // Add notification observers for audio session interruptions
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleAudioSessionInterruption),
                name: AVAudioSession.interruptionNotification,
                object: session
            )

            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleAudioSessionRouteChange),
                name: AVAudioSession.routeChangeNotification,
                object: session
            )

        } catch {
            handleError(error)
        }
    }

    private func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()

        // Play command
        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] _ in
            if self?.isPlaying == false {
                self?.playRadio()
            }
            return .success
        }

        // Pause command
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            if self?.isPlaying == true {
                self?.stopRadio()
            }
            return .success
        }

        // Toggle play/pause
        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.toggleRadio()
            return .success
        }

        // Next station
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.nextStation()
            return .success
        }

        // Previous station
        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.previousStation()
            return .success
        }
    }

    private func updateNowPlayingInfo() {
        var nowPlayingInfo = [String: Any]()

        if let station = currentStation {
            nowPlayingInfo[MPMediaItemPropertyTitle] = station.name
            nowPlayingInfo[MPMediaItemPropertyArtist] = currentlyPlaying
            nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = "FM \(station.frequency)"

            // Set playback rate
            nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0

            // Add app icon as artwork if available
            if let appIcon = UIImage(named: "AppIcon") {
                let artwork = MPMediaItemArtwork(boundsSize: appIcon.size) { _ in appIcon }
                nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
            }
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }

    @objc private func handleAudioSessionInterruption(_ notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        print("🔊 Audio session interruption: \(type)")

        switch type {
        case .began:
            // Audio session was interrupted (phone call, etc.)
            if isPlaying {
                radioPlayer?.pause()
            }
        case .ended:
            // Audio session interruption ended
            if let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) && isPlaying {
                    // Resume playback if it was playing before interruption
                    radioPlayer?.play()
                }
            }
        @unknown default:
            break
        }
    }

    @objc private func handleAudioSessionRouteChange(_ notification: Notification) {
        guard let info = notification.userInfo,
              let reasonValue = info[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }

        print("🔊 Audio session route change: \(reason)")

        switch reason {
        case .oldDeviceUnavailable:
            // Headphones unplugged, pause playback
            if isPlaying {
                Task { @MainActor in
                    self.stopRadio()
                }
            }
        default:
            break
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
              let url = URL(string: station.url) else {
            return
        }

        // Set state immediately for responsive UI after guard checks pass
        isPlaying = true

        print("🔊 Starting radio playback for: \(station.name) at \(station.url)")
        currentlyPlaying = "CONNECTING..."
        signalStrength = 1

        // Update Now Playing info for lock screen
        updateNowPlayingInfo()

        // Create AVPlayer for streaming
        radioPlayer = AVPlayer(url: url)
        radioPlayer?.volume = Float(volume)

        // Observe player status
        playerObserver = radioPlayer?.observe(\.status, options: [.new]) { [weak self] player, _ in
            Task { @MainActor in
                switch player.status {
                case .readyToPlay:
                    // Don't override isPlaying - it's already set for immediate UI feedback
                    if let station = self?.currentStation {
                        self?.currentlyPlaying = "STREAMING: \(station.name)"
                    }
                    self?.signalStrength = 4
                    self?.updateNowPlayingInfo()
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
        trackInfoTimer?.invalidate()
        trackInfoTimer = Timer.scheduledTimer(withTimeInterval: 45.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                if self?.isPlaying == true {
                    self?.simulateTrackChange()
                }
            }
        }

        // Start spectrum animation
        startSpectrumAnimation()
    }

    private func handleRadioError(_ error: Error?) {
        print("🔊 Handling radio error")

        // Clean up the current player first
        playerObserver = nil

        radioPlayer?.pause()
        radioPlayer?.replaceCurrentItem(with: nil)
        radioPlayer = nil

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
        print("🔊 Stopping radio playback")

        // Remove observer first to prevent any callbacks during cleanup
        playerObserver = nil

        // Stop and clean up player
        radioPlayer?.pause()
        radioPlayer?.replaceCurrentItem(with: nil)
        radioPlayer = nil

        // Stop track info updates
        trackInfoTimer?.invalidate()
        trackInfoTimer = nil

        // Stop spectrum animation
        stopSpectrumAnimation()

        isPlaying = false
        currentlyPlaying = "STANDBY"
        signalStrength = 0

        // Clear Now Playing info
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil

        print("🔊 Radio stopped successfully")
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
        updateNowPlayingInfo()
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

        // Set state immediately for responsive UI after permission check passes
        isRecording = true
        recordingStatus = "RECORDING"

        // Reconfigure audio session for recording
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothHFP])
            try session.setActive(true)
        } catch {
            handleError(error)
            isRecording = false
            recordingStatus = "AUDIO SESSION ERROR"
            return
        }

        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]

        // Use custom name if provided, otherwise use timestamp
        let timestamp = Date().timeIntervalSince1970
        let filename: String
        if recordingName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            filename = "recording_\(timestamp).m4a"
        } else {
            // Sanitize the filename to remove invalid characters
            let sanitizedName = recordingName.trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: ":", with: "_")
                .replacingOccurrences(of: "\\", with: "_")
                .replacingOccurrences(of: "*", with: "_")
                .replacingOccurrences(of: "?", with: "_")
                .replacingOccurrences(of: "\"", with: "_")
                .replacingOccurrences(of: "<", with: "_")
                .replacingOccurrences(of: ">", with: "_")
                .replacingOccurrences(of: "|", with: "_")
            filename = "\(sanitizedName)_\(Int(timestamp)).m4a"
        }

        let audioFilename = documentsPath.appendingPathComponent(filename)

        let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 12000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.delegate = audioDelegate
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()

            // Don't override isRecording and recordingStatus - they're already set for immediate UI feedback
            recordingStartTime = Date()

            // Store the recording name for when recording finishes
            currentRecordingName = recordingName.trimmingCharacters(in: .whitespacesAndNewlines)

            // Start timers
            startRecordingTimer()
            startAudioLevelMonitoring()

        } catch {
            handleError(error)
            isRecording = false
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

        // Clear recording name after successful recording
        recordingName = ""

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
        // Prevent multiple rapid calls
        if isPlayingRecording && currentPlayingRecording?.id == recording.id {
            print("🎵 Already playing this recording, ignoring")
            return
        }

        do {
            print("🎵 Starting playback for recording: \(recording.id)")

            // Stop any currently playing recording first
            audioPlayer?.stop()
            audioPlayer = nil
            isPlayingRecording = false
            currentPlayingRecording = nil

            audioPlayer = try AVAudioPlayer(contentsOf: recording.url)
            audioPlayer?.delegate = audioDelegate
            audioPlayer?.volume = Float(volume)

            let playResult = audioPlayer?.play() ?? false
            print("🎵 AudioPlayer play() returned: \(playResult)")

            // Update state immediately on main thread (since we're already @MainActor)
            isPlayingRecording = true
            currentPlayingRecording = recording
            objectWillChange.send() // Force immediate UI update
            print("🎵 Set isPlayingRecording = \(isPlayingRecording), currentPlayingRecording = \(currentPlayingRecording?.id ?? UUID())")
        } catch {
            print("🎵 Error playing recording: \(error)")
            handleError(error)
        }
    }

    func stopRecordingPlayback() {
        print("🎵 Stopping recording playback")
        audioPlayer?.stop()
        audioPlayer = nil

        // Update state immediately (since we're already @MainActor)
        isPlayingRecording = false
        currentPlayingRecording = nil
        objectWillChange.send() // Force immediate UI update
        print("🎵 Set isPlayingRecording = \(isPlayingRecording), currentPlayingRecording = nil")
    }

    func deleteRecording(_ recording: VoiceRecording) {
        do {
            // Stop playback if this recording is currently playing
            if currentPlayingRecording?.id == recording.id {
                stopRecordingPlayback()
            }

            try FileManager.default.removeItem(at: recording.url)
            loadRecordings()
        } catch {
            handleError(error)
        }
    }

    func loadRecordings() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]

        do {
            let files = try FileManager.default.contentsOfDirectory(at: documentsPath, includingPropertiesForKeys: [.creationDateKey], options: [])

            // Load saved metadata
            let savedRecordings = loadRecordingMetadata()

            recordings = files
                .filter { url in
                    // Include .m4a files that either start with "recording_" OR end with timestamp pattern
                    guard url.pathExtension == "m4a" else { return false }
                    let filename = url.lastPathComponent
                    return filename.hasPrefix("recording_") ||
                           filename.range(of: #"_\d+\.m4a$"#, options: .regularExpression) != nil
                }
                .compactMap { url -> VoiceRecording? in
                    guard let creationDate = try? url.resourceValues(forKeys: [.creationDateKey]).creationDate else {
                        return nil
                    }

                    // Check if we have saved metadata for this recording
                    let existingRecording = savedRecordings.first { $0.url.lastPathComponent == url.lastPathComponent }
                    let description = existingRecording?.description ?? ""

                    return VoiceRecording(id: existingRecording?.id ?? UUID(), url: url, date: creationDate, description: description)
                }
                .sorted { $0.date > $1.date }

            hasRecordings = !recordings.isEmpty

        } catch {
            recordings = []
            hasRecordings = false
        }
    }

    func updateRecordingDescription(_ recording: VoiceRecording, description: String) {
        if let index = recordings.firstIndex(where: { $0.id == recording.id }) {
            recordings[index].description = description
            saveRecordingMetadata()
        }
    }

    private func saveRecordingMetadata() {
        if let encoded = try? JSONEncoder().encode(recordings) {
            UserDefaults.standard.set(encoded, forKey: "voice_recording_metadata")
        }
    }

    private func loadRecordingMetadata() -> [VoiceRecording] {
        if let data = UserDefaults.standard.data(forKey: "voice_recording_metadata"),
           let decoded = try? JSONDecoder().decode([VoiceRecording].self, from: data) {
            return decoded
        }
        return []
    }

    func addCustomStation() {
        customStationError = nil

        // Validate input
        guard !customStationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            customStationError = "Station name is required"
            return
        }

        guard !customStationURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            customStationError = "Station URL is required"
            return
        }

        let trimmedURL = customStationURL.trimmingCharacters(in: .whitespacesAndNewlines)

        // Validate URL format and security
        guard let url = URL(string: trimmedURL),
              let scheme = url.scheme?.lowercased(),
              (scheme == "http" || scheme == "https") else {
            customStationError = "Invalid URL format. Must start with http:// or https://"
            return
        }

        // Comprehensive security check - no localhost or private IPs in production
        let host = url.host?.lowercased() ?? ""
        if host.contains("localhost") ||
           host.hasPrefix("127.") ||
           host.hasPrefix("192.168.") ||
           host.hasPrefix("10.") ||
           host.hasPrefix("172.16.") || host.hasPrefix("172.17.") || host.hasPrefix("172.18.") || host.hasPrefix("172.19.") ||
           host.hasPrefix("172.20.") || host.hasPrefix("172.21.") || host.hasPrefix("172.22.") || host.hasPrefix("172.23.") ||
           host.hasPrefix("172.24.") || host.hasPrefix("172.25.") || host.hasPrefix("172.26.") || host.hasPrefix("172.27.") ||
           host.hasPrefix("172.28.") || host.hasPrefix("172.29.") || host.hasPrefix("172.30.") || host.hasPrefix("172.31.") ||
           host.hasPrefix("169.254.") || // Link-local
           host.hasPrefix("fc") || host.hasPrefix("fd") || // IPv6 private
           host == "0.0.0.0" || host.hasPrefix("[::]") {
            customStationError = "Local or private network URLs are not allowed"
            return
        }

        // Check for duplicate stations
        if customStations.contains(where: { $0.url.lowercased() == trimmedURL.lowercased() }) {
            customStationError = "This station URL already exists"
            return
        }

        let trimmedName = customStationName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedFrequency = customStationFrequency.trimmingCharacters(in: .whitespacesAndNewlines)

        let newStation = RadioStation(
            id: UUID(),
            name: trimmedName.uppercased(),
            url: trimmedURL,
            frequency: trimmedFrequency.isEmpty ? "00.0" : trimmedFrequency
        )

        customStations.append(newStation)
        saveCustomStations()

        // Clear the input fields
        customStationName = ""
        customStationURL = ""
        customStationFrequency = ""
        customStationError = nil
    }

    func deleteCustomStation(_ station: RadioStation) {
        // Stop radio if we're deleting the currently playing station
        if currentStation?.id == station.id {
            stopRadio()
        }

        customStations.removeAll { $0.id == station.id }
        saveCustomStations()

        // Update current station if needed
        if currentStation?.id == station.id {
            currentStationIndex = 0
            currentStation = radioStations.first
        } else {
            // Adjust index if needed
            updateCurrentStationIndex()
        }
    }

    func playCustomStation(_ station: RadioStation) {
        // Find the station in the combined list and set it as current
        if let index = radioStations.firstIndex(where: { $0.id == station.id }) {
            stopRadio()
            currentStationIndex = index
            currentStation = station
            playRadio()
        }
    }

    private func updateCurrentStationIndex() {
        if let current = currentStation,
           let index = radioStations.firstIndex(where: { $0.id == current.id }) {
            currentStationIndex = index
        }
    }

    private func saveCustomStations() {
        if let encoded = try? JSONEncoder().encode(customStations) {
            UserDefaults.standard.set(encoded, forKey: "custom_radio_stations")
        }
    }

    private func loadCustomStations() {
        if let data = UserDefaults.standard.data(forKey: "custom_radio_stations"),
           let decoded = try? JSONDecoder().decode([RadioStation].self, from: data) {
            customStations = decoded
        }
    }

    func forceStopAllPlayback() {
        print("🔊 Force stopping all audio playback")

        // Stop radio
        if isPlaying {
            stopRadio()
        }

        // Stop recording
        if isRecording {
            stopRecording()
        }

        // Stop any voice playback
        stopRecordingPlayback()
    }

    private func startSpectrumAnimation() {
        spectrumTimer?.invalidate()
        spectrumTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateSpectrumLevels()
            }
        }
    }

    private func stopSpectrumAnimation() {
        spectrumTimer?.invalidate()
        spectrumTimer = nil
        spectrumLevels = Array(repeating: 0, count: 20)
    }

    private func updateSpectrumLevels() {
        // Simulate spectrum analyzer levels with realistic audio patterns
        for i in 0..<20 {
            // Create frequency-dependent behavior (bass higher, treble lower)
            let bassBoost = i < 5 ? 1.3 : 1.0
            let trebleReduce = i > 15 ? 0.7 : 1.0

            // Random variation with some smoothing
            let targetLevel = CGFloat.random(in: 0.2...0.95) * bassBoost * trebleReduce

            // Smooth transition
            let currentLevel = spectrumLevels[i]
            spectrumLevels[i] = currentLevel + (targetLevel - currentLevel) * 0.3

            // Add occasional peaks
            if Double.random(in: 0...1) > 0.92 {
                spectrumLevels[i] = min(1.0, spectrumLevels[i] * 1.4)
            }
        }
    }

}

// Separate NSObject-based delegate handler since BaseViewModel doesn't inherit from NSObject
private class AudioDelegateHandler: NSObject {
    weak var viewModel: AudioViewModel?

    init(viewModel: AudioViewModel) {
        self.viewModel = viewModel
        super.init()
    }
}

extension AudioDelegateHandler: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in
            if flag {
                viewModel?.loadRecordings()
                // Set the custom name as description for the most recent recording
                if let vm = viewModel, !vm.currentRecordingName.isEmpty, let mostRecent = vm.recordings.first {
                    vm.updateRecordingDescription(mostRecent, description: vm.currentRecordingName)
                }
                viewModel?.currentRecordingName = ""
            } else {
                viewModel?.recordingStatus = "RECORDING FAILED"
            }
        }
    }
}

extension AudioDelegateHandler: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            viewModel?.isPlayingRecording = false
            viewModel?.currentPlayingRecording = nil
            viewModel?.objectWillChange.send() // Force UI update when playback finishes
            print("🎵 Playback finished, cleared state")
        }
    }
}

struct RadioStation: Identifiable, Codable {
    let id: UUID
    let name: String
    let url: String
    let frequency: String
}

struct VoiceRecording: Identifiable, Codable, Equatable {
    let id: UUID
    let url: URL
    let date: Date
    var description: String

    static func == (lhs: VoiceRecording, rhs: VoiceRecording) -> Bool {
        return lhs.id == rhs.id
    }

    var duration: String {
        // Use cached duration if available
        if let cached = AudioViewModel.getCachedDuration(for: url) {
            return cached
        }

        do {
            let audioPlayer = try AVAudioPlayer(contentsOf: url)
            let duration = audioPlayer.duration
            let minutes = Int(duration) / 60
            let seconds = Int(duration) % 60
            let formattedDuration = String(format: "%02d:%02d", minutes, seconds)

            // Cache the result
            AudioViewModel.setCachedDuration(formattedDuration, for: url)
            return formattedDuration
        } catch {
            return "00:00"
        }
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM dd, HH:mm"
        return formatter.string(from: date)
    }

    var displayName: String {
        return description.isEmpty ? "REC_\(String(format: "%.0f", date.timeIntervalSince1970))" : description
    }
}

// Thread-safe duration cache
private class DurationCache {
    static let shared = DurationCache()

    private let lock = NSLock()
    private var cache: [URL: String] = [:]

    private init() {}

    func getDuration(for url: URL) -> String? {
        lock.lock()
        defer { lock.unlock() }
        return cache[url]
    }

    func setDuration(_ duration: String, for url: URL) {
        lock.lock()
        defer { lock.unlock() }
        cache[url] = duration
    }
}