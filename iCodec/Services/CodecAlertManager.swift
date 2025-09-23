import SwiftUI
import AVFoundation
import UserNotifications
import UIKit

@MainActor
class CodecAlertManager: NSObject, ObservableObject {
    static let shared = CodecAlertManager()

    @Published var currentAlert: CodecAlert?
    @Published var isShowingAlert = false
    @Published var badgeCount = 0

    private var audioPlayer: AVAudioPlayer?
    private var buzzerTimer: Timer?
    private var pendingAlerts: [CodecAlert] = []

    override init() {
        super.init()
        setupNotifications()
        loadBadgeCount()
    }

    private func setupNotifications() {
        UNUserNotificationCenter.current().delegate = self

        // Request notification permissions with badge updates
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error)")
            }
        }
    }

    func triggerCodecAlert(title: String, message: String, priority: CodecAlertPriority = .medium) {
        let alert = CodecAlert(
            id: UUID(),
            title: title,
            message: message,
            priority: priority,
            timestamp: Date()
        )

        // If app is in foreground, show immediate alert
        if UIApplication.shared.applicationState == .active {
            showImmediateAlert(alert)
        } else {
            // App is in background, send notification and increment badge
            sendBackgroundNotification(alert)
        }
    }

    private func showImmediateAlert(_ alert: CodecAlert) {
        print("🚨 Showing immediate codec alert: \(alert.title)")
        currentAlert = alert
        isShowingAlert = true
        playCodecBuzzer()

        // Increment badge even for foreground alerts
        incrementBadge()
    }

    private func sendBackgroundNotification(_ alert: CodecAlert) {
        let content = UNMutableNotificationContent()
        content.title = "◄◄ CODEC INCOMING ►►"
        content.body = "\(alert.title): \(alert.message)"
        content.sound = UNNotificationSound(named: UNNotificationSoundName("codec_buzz.wav"))

        // Increment badge
        incrementBadge()
        content.badge = NSNumber(value: badgeCount)

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        let request = UNNotificationRequest(identifier: alert.id.uuidString, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error sending codec notification: \(error)")
            }
        }
    }

    private func playCodecBuzzer() {
        print("🔊 Starting codec buzzer")

        // Immediately play the initial buzz
        playBuzzSound()

        // Start pulsing buzz pattern
        buzzerTimer = Timer.scheduledTimer(withTimeInterval: 1.2, repeats: true) { _ in
            Task { @MainActor in
                print("🔊 Buzz pulse")
                self.playBuzzSound()
            }
        }

        // Stop buzzing after 8 seconds or when alert is dismissed
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
            print("🔊 Stopping codec buzzer")
            self.stopBuzzer()
        }
    }

    private func createCodecBuzzSound() {
        // Generate a codec-style buzz sound using AVAudioEngine
        let engine = AVAudioEngine()
        let playerNode = AVAudioPlayerNode()
        let mixer = engine.mainMixerNode

        engine.attach(playerNode)
        engine.connect(playerNode, to: mixer, format: mixer.outputFormat(forBus: 0))

        // Create buzz tone similar to MGS codec
        let sampleRate = 44100.0
        let frameCount = AVAudioFrameCount(sampleRate * 0.3) // 0.3 second buzz

        guard let buffer = AVAudioPCMBuffer(pcmFormat: mixer.outputFormat(forBus: 0), frameCapacity: frameCount) else {
            return
        }

        buffer.frameLength = frameCount

        let channels = Int(buffer.format.channelCount)
        let frames = Int(buffer.frameLength)

        // Generate buzz pattern - combination of 800Hz and 1200Hz tones
        for frame in 0..<frames {
            let time = Double(frame) / sampleRate
            let buzz1 = sin(2.0 * .pi * 800.0 * time) * 0.3 // 800Hz base
            let buzz2 = sin(2.0 * .pi * 1200.0 * time) * 0.2 // 1200Hz harmonic
            let envelope = max(0, 1.0 - time / 0.3) // Fade out
            let sample = Float((buzz1 + buzz2) * envelope * 0.5)

            for channel in 0..<channels {
                buffer.floatChannelData?[channel][frame] = sample
            }
        }

        do {
            try engine.start()
            playerNode.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
            playerNode.play()
        } catch {
            print("Error creating codec buzz: \(error)")
        }
    }

    private func playBuzzSound() {
        print("🔊 Playing buzz sound")

        // Play system sound with haptic feedback
        AudioServicesPlaySystemSound(1519) // Peek haptic

        // Play multiple system sounds for a buzz effect
        AudioServicesPlaySystemSound(1103) // Begin recording

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            AudioServicesPlaySystemSound(1104) // Key press
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            AudioServicesPlaySystemSound(1105) // Key press
        }

        // Also play tactical sound
        TacticalSoundPlayer.playCodecBuzz()

        // Force a notification sound as backup
        AudioServicesPlaySystemSound(1005) // New mail sound
    }

    func dismissAlert() {
        isShowingAlert = false
        currentAlert = nil
        stopBuzzer()
        clearBadge()
    }

    private func stopBuzzer() {
        buzzerTimer?.invalidate()
        buzzerTimer = nil
        audioPlayer?.stop()
    }

    private func incrementBadge() {
        badgeCount += 1
        updateAppBadge()
        saveBadgeCount()
    }

    func clearBadge() {
        badgeCount = 0
        updateAppBadge()
        saveBadgeCount()
    }

    private func updateAppBadge() {
        UNUserNotificationCenter.current().setBadgeCount(badgeCount) { error in
            if let error = error {
                print("Error setting badge count: \(error)")
            }
        }
    }

    private func saveBadgeCount() {
        UserDefaults.standard.set(badgeCount, forKey: "codec_badge_count")
    }

    private func loadBadgeCount() {
        badgeCount = UserDefaults.standard.integer(forKey: "codec_badge_count")
        updateAppBadge()
    }
}

extension CodecAlertManager: UNUserNotificationCenterDelegate {
    // Handle notification when app is in foreground
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {

        Task { @MainActor in
            print("🔔 Notification received while app active: \(notification.request.identifier)")

            // Handle scheduled alert completion - add to history
            handleScheduledAlertCompletion(notificationId: notification.request.identifier)

            // Show codec alert if app is active
            if let scheduledAlert = SharedDataManager.shared.alertsViewModel.scheduledAlerts.first(where: { $0.id.uuidString == notification.request.identifier }) {
                print("🚨 Triggering codec alert for scheduled alert: \(scheduledAlert.title)")
                triggerCodecAlert(
                    title: scheduledAlert.title,
                    message: scheduledAlert.message ?? "",
                    priority: scheduledAlert.priority.toCodecPriority()
                )
                // Don't show the standard notification banner when we show codec alert
                completionHandler([.badge])
            } else {
                print("⚠️ Could not find scheduled alert for notification: \(notification.request.identifier)")
                // Show standard notification if we can't find the scheduled alert
                completionHandler([.banner, .sound, .badge])
            }
        }
    }

    // Handle notification tap
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {

        Task { @MainActor in
            // Clear badge when user taps notification
            clearBadge()

            // Handle scheduled alert completion - add to history
            handleScheduledAlertCompletion(notificationId: response.notification.request.identifier)
        }

        completionHandler()
    }

    private func handleScheduledAlertCompletion(notificationId: String) {
        // Find and process the scheduled alert that triggered this notification
        let alertsViewModel = SharedDataManager.shared.alertsViewModel

        if let scheduledAlert = alertsViewModel.scheduledAlerts.first(where: { $0.id.uuidString == notificationId }) {
            // Create history entry for the completed alert
            let historyEntry = AlertEntry(
                id: UUID(),
                title: scheduledAlert.title,
                message: scheduledAlert.message,
                timestamp: Date(),
                priority: scheduledAlert.priority
            )

            // Add to alert history
            alertsViewModel.addToHistory(historyEntry)

            // Remove from scheduled alerts if it's not repeating
            if scheduledAlert.repeatOption == .none {
                alertsViewModel.deleteScheduledAlert(scheduledAlert)
            }
        }
    }
}

struct CodecAlert: Identifiable {
    let id: UUID
    let title: String
    let message: String
    let priority: CodecAlertPriority
    let timestamp: Date
}

enum CodecAlertPriority {
    case low, medium, high, critical

    var color: Color {
        switch self {
        case .low: return .gray
        case .medium: return .blue
        case .high: return .orange
        case .critical: return .red
        }
    }

    var glyphCode: String {
        switch self {
        case .low: return "◦"
        case .medium: return "●"
        case .high: return "▲"
        case .critical: return "⬥"
        }
    }
}

// MARK: - Codec Alert View
struct CodecAlertView: View {
    let alert: CodecAlert
    let onDismiss: () -> Void
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var isVisible = false
    @State private var pulseAnimation = false

    var body: some View {
        ZStack {
            // Background overlay
            Color.black.opacity(0.8)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissAlert()
                }

            // Codec terminal window
            VStack(spacing: 0) {
                // Header bar
                HStack {
                    Text("◄◄ CODEC INCOMING ►►")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(.black)
                        .fontWeight(.bold)

                    Spacer()

                    Button(action: dismissAlert) {
                        Text("✕")
                            .font(.system(size: 16, design: .monospaced))
                            .foregroundColor(.black)
                            .fontWeight(.bold)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.yellow)

                // Content area
                VStack(spacing: 16) {
                    // Priority indicator
                    HStack {
                        Text(alert.priority.glyphCode)
                            .font(.system(size: 20, design: .monospaced))
                            .foregroundColor(alert.priority.color)
                            .scaleEffect(pulseAnimation ? 1.2 : 1.0)
                            .animation(.easeInOut(duration: 0.8).repeatForever(), value: pulseAnimation)

                        Text("PRIORITY: \(alert.priority)".uppercased())
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(themeManager.primaryColor)
                            .fontWeight(.bold)

                        Spacer()
                    }

                    // Message content
                    VStack(alignment: .leading, spacing: 8) {
                        Text(alert.title)
                            .font(.system(size: 16, design: .monospaced))
                            .foregroundColor(themeManager.primaryColor)
                            .fontWeight(.bold)

                        Text(alert.message)
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundColor(themeManager.textColor)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // Bottom actions
                    HStack {
                        Spacer()

                        CodecButton(title: "ROGER", action: dismissAlert, style: .primary, size: .medium)
                    }
                }
                .padding(20)
                .background(themeManager.backgroundColor)
            }
            .frame(maxWidth: 320)
            .overlay(
                RoundedRectangle(cornerRadius: 0)
                    .stroke(themeManager.primaryColor, lineWidth: 2)
            )
            .scaleEffect(isVisible ? 1.0 : 0.8)
            .opacity(isVisible ? 1.0 : 0.0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                isVisible = true
                pulseAnimation = true
            }
        }
    }

    private func dismissAlert() {
        withAnimation(.easeOut(duration: 0.3)) {
            isVisible = false
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onDismiss()
        }
    }
}