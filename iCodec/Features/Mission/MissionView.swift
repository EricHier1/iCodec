import SwiftUI

struct MissionView: View {
    @StateObject private var viewModel = MissionViewModel()
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("MISSION SCHEDULE")
                    .font(.system(size: 16, design: .monospaced))
                    .foregroundColor(themeManager.primaryColor)
                    .fontWeight(.bold)

                Spacer()

                CodecButton(title: "NEW MISSION", action: {
                    viewModel.showNewMissionDialog = true
                }, style: .primary, size: .medium)
            }
            .padding(.horizontal, 16)

            ScrollView {
                VStack(spacing: 16) {
                    // Current mission
                    currentMissionSection

                    // Mission queue
                    missionQueueSection
                }
                .padding(.horizontal, 16)
            }
        }
        .background(themeManager.backgroundColor)
        .sheet(isPresented: $viewModel.showNewMissionDialog) {
            NewMissionSheet(viewModel: viewModel)
        }
    }

    private var currentMissionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CURRENT OBJECTIVE")
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(themeManager.accentColor)
                .fontWeight(.bold)

            if let currentMission = viewModel.currentMission {
                MissionCard(mission: currentMission, isActive: true)
            } else {
                VStack(spacing: 8) {
                    Text("No active mission")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(themeManager.textColor)

                    Text("Select or create a mission to begin")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(themeManager.textColor.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .padding(16)
                .background(themeManager.surfaceColor.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(themeManager.primaryColor.opacity(0.3), lineWidth: 1)
                )
                .cornerRadius(8)
            }
        }
    }

    private var missionQueueSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("MISSION QUEUE")
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(themeManager.accentColor)
                .fontWeight(.bold)

            LazyVStack(spacing: 8) {
                ForEach(viewModel.missions) { mission in
                    MissionCard(mission: mission, isActive: false)
                        .onTapGesture {
                            viewModel.setCurrentMission(mission)
                        }
                }

                if viewModel.missions.isEmpty {
                    Text("No missions scheduled")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(themeManager.textColor.opacity(0.7))
                        .frame(maxWidth: .infinity)
                        .padding(16)
                }
            }
        }
    }
}

struct MissionCard: View {
    let mission: Mission
    let isActive: Bool
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(mission.name ?? "Untitled Mission")
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(isActive ? themeManager.accentColor : themeManager.primaryColor)
                    .fontWeight(.bold)

                Spacer()

                priorityIndicator
            }

            if let description = mission.missionDescription {
                Text(description)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(themeManager.textColor.opacity(0.8))
                    .lineLimit(2)
            }

            // Progress bar
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("PROGRESS")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(themeManager.textColor.opacity(0.7))

                    Spacer()

                    Text("\(Int(mission.progress))%")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(themeManager.primaryColor)
                }

                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(themeManager.surfaceColor)
                        .frame(height: 4)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(progressColor)
                        .frame(width: progressWidth, height: 4)
                }
            }
        }
        .padding(12)
        .background(isActive ? themeManager.primaryColor.opacity(0.1) : themeManager.surfaceColor.opacity(0.2))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isActive ? themeManager.primaryColor : themeManager.primaryColor.opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(8)
    }

    private var priorityIndicator: some View {
        let priority = Priority(rawValue: mission.priority ?? "medium") ?? .medium
        return Text(priority.rawValue.uppercased())
            .font(.system(size: 8, design: .monospaced))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(priority.color.opacity(0.2))
            .foregroundColor(priority.color)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(priority.color, lineWidth: 1)
            )
            .cornerRadius(4)
    }

    private var progressWidth: CGFloat {
        CGFloat(mission.progress / 100) * 200 // Approximate width
    }

    private var progressColor: Color {
        let progress = mission.progress
        if progress < 25 { return themeManager.errorColor }
        else if progress < 75 { return themeManager.warningColor }
        else { return themeManager.successColor }
    }
}

struct NewMissionSheet: View {
    @ObservedObject var viewModel: MissionViewModel
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var description = ""
    @State private var priority: Priority = .medium
    @State private var deadline = Date()
    @State private var progress: Double = 0

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("NEW MISSION")
                    .font(.system(size: 18, design: .monospaced))
                    .foregroundColor(themeManager.primaryColor)
                    .fontWeight(.bold)

                VStack(spacing: 16) {
                    TextField("Mission title...", text: $title)
                        .textFieldStyle(CodecTextFieldStyle())

                    TextField("Mission objectives...", text: $description, axis: .vertical)
                        .textFieldStyle(CodecTextFieldStyle())
                        .lineLimit(3...6)

                    HStack {
                        Text("Priority:")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(themeManager.textColor)

                        Picker("Priority", selection: $priority) {
                            ForEach(Priority.allCases, id: \.self) { priority in
                                Text(priority.rawValue.uppercased())
                                    .tag(priority)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }

                    HStack {
                        Text("Progress:")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(themeManager.textColor)

                        Slider(value: $progress, in: 0...100, step: 5)
                            .accentColor(themeManager.primaryColor)

                        Text("\(Int(progress))%")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(themeManager.primaryColor)
                            .frame(width: 40)
                    }
                }

                Spacer()

                HStack(spacing: 16) {
                    CodecButton(title: "CANCEL", action: {
                        dismiss()
                    }, style: .secondary, size: .fullWidth)

                    CodecButton(title: "CREATE", action: {
                        viewModel.createMission(
                            title: title,
                            description: description,
                            priority: priority,
                            progress: progress
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

struct CodecTextFieldStyle: TextFieldStyle {
    @EnvironmentObject private var themeManager: ThemeManager

    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(.system(size: 14, design: .monospaced))
            .foregroundColor(themeManager.textColor)
            .padding(12)
            .background(themeManager.surfaceColor.opacity(0.3))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(themeManager.primaryColor.opacity(0.5), lineWidth: 1)
            )
            .cornerRadius(8)
    }
}

@MainActor
class MissionViewModel: BaseViewModel {
    @Published var missions: [Mission] = []
    @Published var currentMission: Mission?
    @Published var showNewMissionDialog = false

    func createMission(title: String, description: String, priority: Priority, progress: Double) {
        // This would normally use Core Data
        // For now, we'll just simulate mission creation
        print("Creating mission: \(title)")
    }

    func setCurrentMission(_ mission: Mission) {
        currentMission = mission
    }
}

enum Priority: String, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"

    var color: Color {
        switch self {
        case .low: return .gray
        case .medium: return .blue
        case .high: return .orange
        case .critical: return .red
        }
    }
}

// Extension to add missionDescription to Mission
extension Mission {
    var missionDescription: String? {
        get { return "Mission objectives and details..." }
    }

    var priority: String? {
        get { return "medium" }
    }

    var progress: Double {
        get { return 0.0 }
    }
}