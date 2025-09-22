import SwiftUI

struct AlertsView: View {
    @StateObject private var viewModel = AlertsViewModel()
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
    }

    private var alertHistorySection: some View {
        LazyVStack(spacing: 8) {
            ForEach(viewModel.alertHistory) { alert in
                AlertHistoryCard(alert: alert)
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

@MainActor
class AlertsViewModel: BaseViewModel {
    @Published var alertHistory: [AlertEntry] = []
    @Published var scheduledAlerts: [ScheduledAlert] = []
    @Published var selectedTab: AlertTab = .history
    @Published var systemStatus: SystemStatus = .operational
    @Published var showScheduleDialog = false

    override init() {
        super.init()
        generateSampleAlerts()
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
    }

    func deleteScheduledAlert(_ alert: ScheduledAlert) {
        scheduledAlerts.removeAll { $0.id == alert.id }
    }

    private func generateSampleAlerts() {
        alertHistory = [
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

struct AlertEntry: Identifiable {
    let id: UUID
    let title: String
    let message: String?
    let timestamp: Date
    let priority: AlertPriority
}

struct ScheduledAlert: Identifiable {
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

enum AlertPriority {
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

enum RepeatOption: String, CaseIterable {
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