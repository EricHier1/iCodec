import SwiftUI
import UserNotifications
import AVFoundation

struct AlertsView: View {
    @ObservedObject private var viewModel = SharedDataManager.shared.alertsViewModel
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("ALERT SYSTEM")
                    .font(.system(size: 16, design: .monospaced))
                    .foregroundColor(themeManager.primaryColor)
                    .fontWeight(.bold)

                Spacer()

                HStack(spacing: 8) {
                    CodecButton(title: "TEST", action: {
                        viewModel.testAlert()
                    }, style: .secondary, size: .small)

                    CodecButton(title: "SCHEDULE", action: {
                        viewModel.showScheduleDialog = true
                    }, style: .primary, size: .medium)
                }
            }
            .padding(.horizontal, 16)

            // Status indicator
            HStack {
                Circle()
                    .fill(viewModel.systemStatus.color)
                    .frame(width: 8, height: 8)

                Text(viewModel.systemStatus.message)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(themeManager.textColor)

                Spacer()
            }
            .padding(.horizontal, 16)

            // Alert tabs
            HStack(spacing: 0) {
                ForEach(AlertTab.allCases, id: \.self) { tab in
                    Button(action: {
                        viewModel.selectedTab = tab
                    }) {
                        Text(tab.rawValue)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(viewModel.selectedTab == tab ? themeManager.backgroundColor : themeManager.primaryColor)
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(viewModel.selectedTab == tab ? themeManager.primaryColor : Color.clear)
                    }
                    .overlay(
                        Rectangle()
                            .stroke(themeManager.primaryColor, lineWidth: 1)
                    )
                }
            }
            .padding(.horizontal, 16)

            // Content
            ScrollView {
                switch viewModel.selectedTab {
                case .history:
                    alertHistorySection
                case .scheduled:
                    scheduledAlertsSection
                }
            }
        }
        .background(themeManager.backgroundColor)
        .sheet(isPresented: $viewModel.showScheduleDialog) {
            ScheduleAlertSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showEditDialog) {
            EditAlertSheet(viewModel: viewModel)
        }
    }

    private var alertHistorySection: some View {
        LazyVStack(spacing: 8) {
            ForEach(viewModel.alertHistory) { alert in
                AlertHistoryCard(alert: alert)
                    .contextMenu {
                        Button("Delete Alert", systemImage: "trash", role: .destructive) {
                            viewModel.deleteAlertHistory(alert)
                        }
                    }
            }

            if viewModel.alertHistory.isEmpty {
                Text("No alerts in history")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(themeManager.textColor.opacity(0.7))
                    .frame(maxWidth: .infinity)
                    .padding(32)
            }
        }
        .padding(.horizontal, 16)
    }

    private var scheduledAlertsSection: some View {
        LazyVStack(spacing: 8) {
            ForEach(viewModel.scheduledAlerts) { alert in
                ScheduledAlertCard(alert: alert, onDelete: {
                    viewModel.deleteScheduledAlert(alert)
                })
                .contextMenu {
                    Button("Edit Alert", systemImage: "pencil") {
                        viewModel.editScheduledAlert(alert)
                    }
                    Button("Delete Alert", systemImage: "trash", role: .destructive) {
                        viewModel.deleteScheduledAlert(alert)
                    }
                }
            }

            if viewModel.scheduledAlerts.isEmpty {
                Text("No scheduled alerts")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(themeManager.textColor.opacity(0.7))
                    .frame(maxWidth: .infinity)
                    .padding(32)
            }
        }
        .padding(.horizontal, 16)
    }
}

struct AlertHistoryCard: View {
    let alert: AlertEntry
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(alert.title)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(themeManager.primaryColor)
                    .fontWeight(.bold)

                if let message = alert.message {
                    Text(message)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(themeManager.textColor.opacity(0.8))
                        .lineLimit(2)
                }

                Text(alert.timestamp, style: .relative)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(themeManager.textColor.opacity(0.6))
            }

            Spacer()

            priorityBadge
        }
        .padding(10)
        .background(themeManager.surfaceColor.opacity(0.2))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(themeManager.primaryColor.opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(6)
    }

    private var priorityBadge: some View {
        Circle()
            .fill(alert.priority.color)
            .frame(width: 8, height: 8)
    }
}

struct ScheduledAlertCard: View {
    let alert: ScheduledAlert
    let onDelete: () -> Void
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(alert.title)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(themeManager.primaryColor)
                    .fontWeight(.bold)

                if let message = alert.message {
                    Text(message)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(themeManager.textColor.opacity(0.8))
                        .lineLimit(2)
                }

                Text(alert.scheduledTime, style: .date)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(themeManager.accentColor)
            }

            Spacer()

            Button(action: onDelete) {
                Text("×")
                    .font(.system(size: 16, design: .monospaced))
                    .foregroundColor(themeManager.errorColor)
                    .fontWeight(.bold)
            }
        }
        .padding(10)
        .background(themeManager.surfaceColor.opacity(0.2))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(themeManager.primaryColor.opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(6)
    }
}

struct ScheduleAlertSheet: View {
    @ObservedObject var viewModel: AlertsViewModel
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var message = ""
    @State private var scheduledTime = Date().addingTimeInterval(3600)
    @State private var repeatOption: RepeatOption = .none

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("SCHEDULE ALERT")
                    .font(.system(size: 18, design: .monospaced))
                    .foregroundColor(themeManager.primaryColor)
                    .fontWeight(.bold)

                VStack(spacing: 16) {
                    TextField("Alert title...", text: $title)
                        .textFieldStyle(CodecTextFieldStyle())

                    TextField("Alert message...", text: $message, axis: .vertical)
                        .textFieldStyle(CodecTextFieldStyle())
                        .lineLimit(3...6)

                    DatePicker("Scheduled Time", selection: $scheduledTime, displayedComponents: [.date, .hourAndMinute])
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(themeManager.textColor)

                    HStack {
                        Text("Repeat:")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(themeManager.textColor)

                        Picker("Repeat", selection: $repeatOption) {
                            ForEach(RepeatOption.allCases, id: \.self) { option in
                                Text(option.rawValue)
                                    .tag(option)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                    }
                }

                Spacer()

                HStack(spacing: 16) {
                    CodecButton(title: "CANCEL", action: {
                        dismiss()
                    }, style: .secondary, size: .fullWidth)

                    CodecButton(title: "SCHEDULE", action: {
                        viewModel.scheduleAlert(
                            title: title,
                            message: message,
                            time: scheduledTime,
                            repeatOption: repeatOption
                        )
                        dismiss()
                    }, style: .primary, size: .fullWidth)
                }
            }
            .padding(20)
            .background(themeManager.backgroundColor)
        }
    }
}

struct EditAlertSheet: View {
    @ObservedObject var viewModel: AlertsViewModel
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var message = ""
    @State private var scheduledTime = Date().addingTimeInterval(3600)
    @State private var repeatOption: RepeatOption = .none

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("EDIT ALERT")
                    .font(.system(size: 18, design: .monospaced))
                    .foregroundColor(themeManager.primaryColor)
                    .fontWeight(.bold)

                VStack(spacing: 16) {
                    TextField("Alert title...", text: $title)
                        .textFieldStyle(CodecTextFieldStyle())

                    TextField("Alert message...", text: $message, axis: .vertical)
                        .textFieldStyle(CodecTextFieldStyle())
                        .lineLimit(3...6)

                    DatePicker("Scheduled Time", selection: $scheduledTime, displayedComponents: [.date, .hourAndMinute])
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(themeManager.textColor)

                    HStack {
                        Text("Repeat:")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(themeManager.textColor)

                        Picker("Repeat", selection: $repeatOption) {
                            ForEach(RepeatOption.allCases, id: \.self) { option in
                                Text(option.rawValue)
                                    .tag(option)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                    }
                }

                Spacer()

                HStack(spacing: 16) {
                    CodecButton(title: "CANCEL", action: {
                        dismiss()
                    }, style: .secondary, size: .fullWidth)

                    CodecButton(title: "UPDATE", action: {
                        if let alert = viewModel.alertToEdit {
                            viewModel.updateScheduledAlert(
                                alert,
                                title: title,
                                message: message,
                                time: scheduledTime,
                                repeatOption: repeatOption
                            )
                        }
                        dismiss()
                    }, style: .primary, size: .fullWidth)
                }
            }
            .padding(20)
            .background(themeManager.backgroundColor)
        }
        .onAppear {
            if let alert = viewModel.alertToEdit {
                title = alert.title
                message = alert.message ?? ""
                scheduledTime = alert.scheduledTime
                repeatOption = alert.repeatOption
            }
        }
    }
}

@MainActor
class AlertsViewModel: BaseViewModel {
    @Published var alertHistory: [AlertEntry] = []
    @Published var scheduledAlerts: [ScheduledAlert] = []
    @Published var selectedTab: AlertTab = .history
    @Published var systemStatus: SystemStatus = .operational
    @Published var showScheduleDialog = false
    @Published var showEditDialog = false
    @Published var alertToEdit: ScheduledAlert?

    private let scheduledAlertsStorageKey = "com.erichier.iccodec.alerts.scheduled"
    private let alertHistoryStorageKey = "com.erichier.iccodec.alerts.history"
    private let userDefaults = UserDefaults.standard

    override init() {
        super.init()
        requestNotificationPermission()
        loadPersistedAlerts()

        if alertHistory.isEmpty {
            alertHistory = sampleAlertHistory()
            persistAlertHistory()
        }
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("Notification permission granted")
            } else if let error = error {
                print("Notification permission denied: \(error)")
            }
        }
    }

    func testAlert() {
        let testAlert = AlertEntry(
            id: UUID(),
            title: "Test Alert",
            message: "System test notification",
            timestamp: Date(),
            priority: .medium
        )
        alertHistory.insert(testAlert, at: 0)
        persistAlertHistory()

        // Send immediate test notification
        let content = UNMutableNotificationContent()
        content.title = "iCodec Test Alert"
        content.body = "System test notification successful"
        content.sound = UNNotificationSound.default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "test-\(UUID().uuidString)", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error sending test notification: \(error)")
            }
        }
    }

    func scheduleAlert(title: String, message: String, time: Date, repeatOption: RepeatOption) {
        let scheduledAlert = ScheduledAlert(
            id: UUID(),
            title: title,
            message: message,
            scheduledTime: time,
            repeatOption: repeatOption
        )
        scheduledAlerts.append(scheduledAlert)
        scheduledAlerts.sort { $0.scheduledTime < $1.scheduledTime }
        persistScheduledAlerts()

        // Schedule actual notification
        scheduleNotification(for: scheduledAlert)
    }

    private func scheduleNotification(for alert: ScheduledAlert) {
        let content = UNMutableNotificationContent()
        content.title = alert.title
        content.body = alert.message ?? ""
        content.sound = UNNotificationSound.default

        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: alert.scheduledTime)

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: alert.repeatOption != .none)

        let request = UNNotificationRequest(identifier: alert.id.uuidString, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error)")
            } else {
                print("Notification scheduled for \(alert.scheduledTime)")
            }
        }
    }

    func deleteScheduledAlert(_ alert: ScheduledAlert) {
        scheduledAlerts.removeAll { $0.id == alert.id }
        persistScheduledAlerts()
        // Cancel the notification
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [alert.id.uuidString])
    }

    func deleteAlertHistory(_ alert: AlertEntry) {
        alertHistory.removeAll { $0.id == alert.id }
        persistAlertHistory()
    }

    func editScheduledAlert(_ alert: ScheduledAlert) {
        alertToEdit = alert
        showEditDialog = true
    }

    func updateScheduledAlert(_ alert: ScheduledAlert, title: String, message: String, time: Date, repeatOption: RepeatOption) {
        if let index = scheduledAlerts.firstIndex(where: { $0.id == alert.id }) {
            // Cancel old notification
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [alert.id.uuidString])

            // Update alert
            let updatedAlert = ScheduledAlert(
                id: alert.id,
                title: title,
                message: message,
                scheduledTime: time,
                repeatOption: repeatOption
            )
            scheduledAlerts[index] = updatedAlert
            scheduledAlerts.sort { $0.scheduledTime < $1.scheduledTime }
            persistScheduledAlerts()

            // Schedule new notification
            scheduleNotification(for: updatedAlert)
        }
    }

    private func loadPersistedAlerts() {
        let decoder = JSONDecoder()

        if let scheduledData = userDefaults.data(forKey: scheduledAlertsStorageKey) {
            do {
                scheduledAlerts = try decoder.decode([ScheduledAlert].self, from: scheduledData)
                scheduledAlerts.forEach { scheduleNotification(for: $0) }
            } catch {
                print("Error decoding scheduled alerts: \(error)")
            }
        }

        if let historyData = userDefaults.data(forKey: alertHistoryStorageKey) {
            do {
                alertHistory = try decoder.decode([AlertEntry].self, from: historyData)
            } catch {
                print("Error decoding alert history: \(error)")
            }
        }
    }

    private func persistScheduledAlerts() {
        let encoder = JSONEncoder()

        do {
            if scheduledAlerts.isEmpty {
                userDefaults.removeObject(forKey: scheduledAlertsStorageKey)
            } else {
                let data = try encoder.encode(scheduledAlerts)
                userDefaults.set(data, forKey: scheduledAlertsStorageKey)
            }
        } catch {
            print("Error encoding scheduled alerts: \(error)")
        }
    }

    private func persistAlertHistory() {
        let encoder = JSONEncoder()

        do {
            if alertHistory.isEmpty {
                userDefaults.removeObject(forKey: alertHistoryStorageKey)
            } else {
                let data = try encoder.encode(alertHistory)
                userDefaults.set(data, forKey: alertHistoryStorageKey)
            }
        } catch {
            print("Error encoding alert history: \(error)")
        }
    }

    private func sampleAlertHistory() -> [AlertEntry] {
        [
            AlertEntry(
                id: UUID(),
                title: "Mission Update",
                message: "Objective parameters have been updated",
                timestamp: Date().addingTimeInterval(-1800),
                priority: .medium
            ),
            AlertEntry(
                id: UUID(),
                title: "Security Alert",
                message: "Unauthorized access detected",
                timestamp: Date().addingTimeInterval(-3600),
                priority: .high
            )
        ]
    }
}

struct AlertEntry: Identifiable, Codable {
    let id: UUID
    let title: String
    let message: String?
    let timestamp: Date
    let priority: AlertPriority
}

struct ScheduledAlert: Identifiable, Codable {
    let id: UUID
    let title: String
    let message: String?
    let scheduledTime: Date
    let repeatOption: RepeatOption
}

enum AlertTab: String, CaseIterable {
    case history = "ALERT HISTORY"
    case scheduled = "SCHEDULED ALERTS"
}

enum AlertPriority: String, Codable {
    case low, medium, high, critical

    var color: Color {
        switch self {
        case .low: return .gray
        case .medium: return .blue
        case .high: return .orange
        case .critical: return .red
        }
    }
}

enum RepeatOption: String, CaseIterable, Codable {
    case none = "No repeat"
    case daily = "Daily"
    case weekly = "Weekly"
    case monthly = "Monthly"
}

enum SystemStatus {
    case operational
    case warning
    case error

    var message: String {
        switch self {
        case .operational: return "System operational"
        case .warning: return "System warning"
        case .error: return "System error"
        }
    }

    var color: Color {
        switch self {
        case .operational: return .green
        case .warning: return .orange
        case .error: return .red
        }
    }
}
