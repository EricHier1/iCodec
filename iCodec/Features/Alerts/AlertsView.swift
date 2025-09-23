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
                        TacticalSoundPlayer.playAction()
                        viewModel.testAlert()
                    }, style: .secondary, size: .small)

                    CodecButton(title: "SCHEDULE", action: {
                        TacticalSoundPlayer.playNavigation()
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
                case .scheduled:
                    scheduledAlertsSection
                case .history:
                    alertHistorySection
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
        .sheet(isPresented: $viewModel.showScheduledAlertDetailDialog) {
            if let alert = viewModel.scheduledAlertToView {
                ScheduledAlertDetailView(alert: alert, viewModel: viewModel)
            }
        }
        .sheet(isPresented: $viewModel.showAlertHistoryDetailDialog) {
            if let alert = viewModel.alertHistoryToView {
                AlertHistoryDetailView(alert: alert, viewModel: viewModel)
            }
        }
    }

    private var alertHistorySection: some View {
        LazyVStack(spacing: 8) {
            ForEach(viewModel.alertHistory) { alert in
                AlertHistoryCard(alert: alert)
                    .onTapGesture {
                        viewModel.viewAlertHistoryDetail(alert)
                    }
                    .contextMenu {
                        Button("View Details", systemImage: "eye") {
                            viewModel.viewAlertHistoryDetail(alert)
                        }
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
                ScheduledAlertCard(alert: alert)
                .onTapGesture {
                    viewModel.viewScheduledAlertDetail(alert)
                }
                .contextMenu {
                    Button("View Details", systemImage: "eye") {
                        viewModel.viewScheduledAlertDetail(alert)
                    }
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

            // Priority indicator
            Circle()
                .fill(alert.priority.color)
                .frame(width: 8, height: 8)
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
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
    @Published var selectedTab: AlertTab = .scheduled
    @Published var systemStatus: SystemStatus = .operational
    @Published var showScheduleDialog = false
    @Published var showEditDialog = false
    @Published var alertToEdit: ScheduledAlert?
    @Published var showScheduledAlertDetailDialog = false
    @Published var scheduledAlertToView: ScheduledAlert?
    @Published var showAlertHistoryDetailDialog = false
    @Published var alertHistoryToView: AlertEntry?

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
            DispatchQueue.main.async {
                if granted {
                    self.systemStatus = .operational
                    print("Notification permission granted")
                } else {
                    self.systemStatus = .error
                    if let error = error {
                        print("Notification permission denied: \(error)")
                    }
                }
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

        // Add to history using the new method
        addToHistory(testAlert)

        // Trigger Metal Gear Solid-style codec alert
        CodecAlertManager.shared.triggerCodecAlert(
            title: "Test Alert",
            message: "System test notification successful",
            priority: testAlert.priority.toCodecPriority()
        )
    }

    func scheduleAlert(title: String, message: String, time: Date, repeatOption: RepeatOption, priority: AlertPriority = .medium) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedTitle.isEmpty else { return }

        let scheduledAlert = ScheduledAlert(
            id: UUID(),
            title: trimmedTitle,
            message: trimmedMessage.isEmpty ? nil : trimmedMessage,
            scheduledTime: time,
            repeatOption: repeatOption,
            priority: priority
        )
        scheduledAlerts.append(scheduledAlert)
        scheduledAlerts.sort { $0.scheduledTime < $1.scheduledTime }
        persistScheduledAlerts()

        // Schedule actual notification
        scheduleNotification(for: scheduledAlert)

        print("📅 Scheduled alert: \(trimmedTitle) for \(time)")
    }

    private func scheduleNotification(for alert: ScheduledAlert) {
        let content = UNMutableNotificationContent()
        content.title = "◄◄ CODEC INCOMING ►►"
        content.body = alert.message?.isEmpty == false ? "\(alert.title): \(alert.message!)" : alert.title
        content.sound = UNNotificationSound.default

        guard let trigger = makeTrigger(for: alert) else {
            systemStatus = .error
            return
        }

        let request = UNNotificationRequest(identifier: alert.id.uuidString, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            DispatchQueue.main.async {
                if let error = error {
                    self.systemStatus = .error
                    print("Error scheduling notification: \(error)")
                } else {
                    self.refreshSystemStatus()
                    print("Codec notification scheduled for \(alert.scheduledTime)")

                    // When the notification fires, if app is active, show codec alert
                    // This will be handled by the UNUserNotificationCenterDelegate
                }
            }
        }
    }

    func deleteScheduledAlert(_ alert: ScheduledAlert) {
        scheduledAlerts.removeAll { $0.id == alert.id }
        persistScheduledAlerts()
        // Cancel the notification
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [alert.id.uuidString])
        refreshSystemStatus()
    }

    func deleteAlertHistory(_ alert: AlertEntry) {
        alertHistory.removeAll { $0.id == alert.id }
        persistAlertHistory()
    }

    func addToHistory(_ alert: AlertEntry) {
        alertHistory.insert(alert, at: 0) // Add to beginning for most recent first
        persistAlertHistory()
    }

    func editScheduledAlert(_ alert: ScheduledAlert) {
        alertToEdit = alert
        showEditDialog = true
    }

    func viewScheduledAlertDetail(_ alert: ScheduledAlert) {
        scheduledAlertToView = alert
        showScheduledAlertDetailDialog = true
    }

    func viewAlertHistoryDetail(_ alert: AlertEntry) {
        alertHistoryToView = alert
        showAlertHistoryDetailDialog = true
    }

    func updateScheduledAlert(_ alert: ScheduledAlert, title: String, message: String, time: Date, repeatOption: RepeatOption, priority: AlertPriority = .medium) {
        if let index = scheduledAlerts.firstIndex(where: { $0.id == alert.id }) {
            // Cancel old notification
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [alert.id.uuidString])

            // Update alert
            let updatedAlert = ScheduledAlert(
                id: alert.id,
                title: title,
                message: message,
                scheduledTime: time,
                repeatOption: repeatOption,
                priority: priority
            )
            scheduledAlerts[index] = updatedAlert
            scheduledAlerts.sort { $0.scheduledTime < $1.scheduledTime }
            persistScheduledAlerts()

            // Schedule new notification
            scheduleNotification(for: updatedAlert)
        }
    }

    private func makeTrigger(for alert: ScheduledAlert) -> UNNotificationTrigger? {
        let calendar = Calendar.current
        switch alert.repeatOption {
        case .none:
            if alert.scheduledTime <= Date().addingTimeInterval(1) {
                return UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
            }
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: alert.scheduledTime)
            return UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        case .daily:
            let components = calendar.dateComponents([.hour, .minute], from: alert.scheduledTime)
            return UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        case .weekly:
            var components = calendar.dateComponents([.weekday, .hour, .minute], from: alert.scheduledTime)
            if components.weekday == nil {
                components.weekday = calendar.component(.weekday, from: Date())
            }
            return UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        case .monthly:
            var components = calendar.dateComponents([.day, .hour, .minute], from: alert.scheduledTime)
            if components.day == nil {
                components.day = calendar.component(.day, from: Date())
            }
            return UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        }
    }

    private func refreshSystemStatus() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            DispatchQueue.main.async {
                self.systemStatus = requests.isEmpty ? .operational : .warning
            }
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

        refreshSystemStatus()
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
    let priority: AlertPriority
}

enum AlertTab: String, CaseIterable {
    case scheduled = "SCHEDULED ALERTS"
    case history = "ALERT HISTORY"
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

    func toCodecPriority() -> CodecAlertPriority {
        switch self {
        case .low: return .low
        case .medium: return .medium
        case .high: return .high
        case .critical: return .critical
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

struct ScheduledAlertDetailView: View {
    let alert: ScheduledAlert
    let viewModel: AlertsViewModel
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Header
                HStack {
                    CodecButton(title: "CLOSE", action: {
                        dismiss()
                    }, style: .secondary, size: .small)

                    Spacer()

                    Text("SCHEDULED ALERT DETAILS")
                        .font(.system(size: 16, design: .monospaced))
                        .foregroundColor(themeManager.primaryColor)
                        .fontWeight(.bold)

                    Spacer()

                    CodecButton(title: "EDIT", action: {
                        dismiss()
                        viewModel.editScheduledAlert(alert)
                    }, style: .primary, size: .small)
                }
                .padding(16)
                .background(themeManager.surfaceColor.opacity(0.1))
                .overlay(
                    Rectangle()
                        .fill(themeManager.primaryColor.opacity(0.3))
                        .frame(height: 1),
                    alignment: .bottom
                )

                // Content
                ScrollView {
                    VStack(spacing: 24) {
                        // Alert title and priority
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text(alert.title)
                                    .font(.system(size: 20, design: .monospaced))
                                    .foregroundColor(themeManager.primaryColor)
                                    .fontWeight(.bold)

                                Spacer()

                                priorityIndicator
                            }

                            HStack {
                                Text("STATUS: SCHEDULED")
                                    .font(.system(size: 10, design: .monospaced))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(themeManager.warningColor.opacity(0.2))
                                    .foregroundColor(themeManager.warningColor)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(themeManager.warningColor, lineWidth: 1)
                                    )
                                    .cornerRadius(6)

                                Spacer()
                            }
                        }

                        // Scheduling info
                        VStack(alignment: .leading, spacing: 12) {
                            Text("SCHEDULING INFORMATION")
                                .font(.system(size: 14, design: .monospaced))
                                .foregroundColor(themeManager.accentColor)
                                .fontWeight(.bold)

                            VStack(spacing: 8) {
                                scheduleInfoRow("SCHEDULED TIME", formatDate(alert.scheduledTime))
                                scheduleInfoRow("REPEAT", alert.repeatOption.rawValue)
                                scheduleInfoRow("TIME REMAINING", timeRemaining)
                            }
                        }

                        // Alert message
                        if let message = alert.message, !message.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("ALERT MESSAGE")
                                    .font(.system(size: 14, design: .monospaced))
                                    .foregroundColor(themeManager.accentColor)
                                    .fontWeight(.bold)

                                Text(message)
                                    .font(.system(size: 14, design: .monospaced))
                                    .foregroundColor(themeManager.textColor)
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(16)
                                    .background(themeManager.surfaceColor.opacity(0.2))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(themeManager.primaryColor.opacity(0.3), lineWidth: 1)
                                    )
                                    .cornerRadius(8)
                            }
                        }

                        // Actions
                        VStack(spacing: 12) {
                            Text("ALERT ACTIONS")
                                .font(.system(size: 14, design: .monospaced))
                                .foregroundColor(themeManager.accentColor)
                                .fontWeight(.bold)

                            HStack(spacing: 12) {
                                CodecButton(title: "EDIT ALERT", action: {
                                    dismiss()
                                    viewModel.editScheduledAlert(alert)
                                }, style: .secondary, size: .fullWidth)

                                CodecButton(title: "DELETE ALERT", action: {
                                    viewModel.deleteScheduledAlert(alert)
                                    dismiss()
                                }, style: .primary, size: .fullWidth)
                            }
                        }

                        Spacer(minLength: 20)
                    }
                    .padding(16)
                }
            }
            .background(themeManager.backgroundColor)
            .navigationBarHidden(true)
        }
    }

    private var priorityIndicator: some View {
        Text(alert.priority.rawValue.uppercased())
            .font(.system(size: 10, design: .monospaced))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(alert.priority.color.opacity(0.2))
            .foregroundColor(alert.priority.color)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(alert.priority.color, lineWidth: 1)
            )
            .cornerRadius(6)
    }

    private func scheduleInfoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(themeManager.textColor.opacity(0.7))
                .fontWeight(.bold)
                .frame(width: 120, alignment: .leading)

            Text(value)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(themeManager.primaryColor)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(themeManager.surfaceColor.opacity(0.1))
        .cornerRadius(6)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM dd, yyyy HH:mm"
        return formatter.string(from: date)
    }

    private var timeRemaining: String {
        let interval = alert.scheduledTime.timeIntervalSinceNow
        if interval <= 0 {
            return "Overdue"
        }

        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60

        if hours > 24 {
            let days = hours / 24
            return "\(days)d \(hours % 24)h"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

struct AlertHistoryDetailView: View {
    let alert: AlertEntry
    let viewModel: AlertsViewModel
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Header
                HStack {
                    CodecButton(title: "CLOSE", action: {
                        dismiss()
                    }, style: .secondary, size: .small)

                    Spacer()

                    Text("ALERT HISTORY DETAILS")
                        .font(.system(size: 16, design: .monospaced))
                        .foregroundColor(themeManager.primaryColor)
                        .fontWeight(.bold)

                    Spacer()

                    CodecButton(title: "DELETE", action: {
                        viewModel.deleteAlertHistory(alert)
                        dismiss()
                    }, style: .primary, size: .small)
                }
                .padding(16)
                .background(themeManager.surfaceColor.opacity(0.1))
                .overlay(
                    Rectangle()
                        .fill(themeManager.primaryColor.opacity(0.3))
                        .frame(height: 1),
                    alignment: .bottom
                )

                // Content
                ScrollView {
                    VStack(spacing: 24) {
                        // Alert title and priority
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text(alert.title)
                                    .font(.system(size: 20, design: .monospaced))
                                    .foregroundColor(themeManager.primaryColor)
                                    .fontWeight(.bold)

                                Spacer()

                                priorityIndicator
                            }

                            HStack {
                                Text("STATUS: COMPLETED")
                                    .font(.system(size: 10, design: .monospaced))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(themeManager.successColor.opacity(0.2))
                                    .foregroundColor(themeManager.successColor)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(themeManager.successColor, lineWidth: 1)
                                    )
                                    .cornerRadius(6)

                                Spacer()

                                Text("TRIGGERED: \(formatDate(alert.timestamp))")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(themeManager.textColor.opacity(0.7))
                            }
                        }

                        // Alert message
                        if let message = alert.message, !message.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("ALERT MESSAGE")
                                    .font(.system(size: 14, design: .monospaced))
                                    .foregroundColor(themeManager.accentColor)
                                    .fontWeight(.bold)

                                Text(message)
                                    .font(.system(size: 14, design: .monospaced))
                                    .foregroundColor(themeManager.textColor)
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(16)
                                    .background(themeManager.surfaceColor.opacity(0.2))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(themeManager.primaryColor.opacity(0.3), lineWidth: 1)
                                    )
                                    .cornerRadius(8)
                            }
                        }

                        // Timing info
                        VStack(alignment: .leading, spacing: 12) {
                            Text("TIMING INFORMATION")
                                .font(.system(size: 14, design: .monospaced))
                                .foregroundColor(themeManager.accentColor)
                                .fontWeight(.bold)

                            VStack(spacing: 8) {
                                timingInfoRow("TRIGGERED", formatDate(alert.timestamp))
                                timingInfoRow("TIME AGO", timeAgo)
                            }
                        }

                        Spacer(minLength: 20)
                    }
                    .padding(16)
                }
            }
            .background(themeManager.backgroundColor)
            .navigationBarHidden(true)
        }
    }

    private var priorityIndicator: some View {
        Text(alert.priority.rawValue.uppercased())
            .font(.system(size: 10, design: .monospaced))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(alert.priority.color.opacity(0.2))
            .foregroundColor(alert.priority.color)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(alert.priority.color, lineWidth: 1)
            )
            .cornerRadius(6)
    }

    private func timingInfoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(themeManager.textColor.opacity(0.7))
                .fontWeight(.bold)
                .frame(width: 120, alignment: .leading)

            Text(value)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(themeManager.primaryColor)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(themeManager.surfaceColor.opacity(0.1))
        .cornerRadius(6)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM dd, yyyy HH:mm"
        return formatter.string(from: date)
    }

    private var timeAgo: String {
        let interval = Date().timeIntervalSince(alert.timestamp)
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60

        if hours > 24 {
            let days = hours / 24
            return "\(days) day\(days == 1 ? "" : "s") ago"
        } else if hours > 0 {
            return "\(hours) hour\(hours == 1 ? "" : "s") ago"
        } else if minutes > 0 {
            return "\(minutes) minute\(minutes == 1 ? "" : "s") ago"
        } else {
            return "Just now"
        }
    }
}
