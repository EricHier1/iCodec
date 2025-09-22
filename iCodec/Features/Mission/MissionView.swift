import SwiftUI
import CoreData

struct MissionView: View {
    @ObservedObject private var viewModel = SharedDataManager.shared.missionViewModel
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

                    // Completed missions
                    completedMissionsSection
                }
                .padding(.horizontal, 16)
            }
        }
        .background(themeManager.backgroundColor)
        .sheet(isPresented: $viewModel.showNewMissionDialog) {
            NewMissionSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showEditMissionDialog) {
            EditMissionSheet(viewModel: viewModel)
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

            VStack(spacing: 8) {
                ForEach(viewModel.missions) { mission in
                    MissionCard(mission: mission, isActive: false)
                        .onTapGesture {
                            viewModel.setCurrentMission(mission)
                        }
                        .onLongPressGesture {
                            viewModel.editMission(mission)
                        }
                        .contextMenu {
                            Button("Edit Mission", systemImage: "pencil") {
                                viewModel.editMission(mission)
                            }
                            Button("Delete Mission", systemImage: "trash", role: .destructive) {
                                viewModel.deleteMission(mission)
                            }
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

    private var completedMissionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("COMPLETED MISSIONS")
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(themeManager.successColor)
                .fontWeight(.bold)

            VStack(spacing: 8) {
                ForEach(viewModel.completedMissions) { mission in
                    MissionCard(mission: mission, isActive: false, isCompleted: true)
                        .contextMenu {
                            Button("Reactivate Mission", systemImage: "arrow.clockwise") {
                                viewModel.reactivateMission(mission)
                            }
                            Button("Delete Mission", systemImage: "trash", role: .destructive) {
                                viewModel.deleteMission(mission)
                            }
                        }
                }

                if viewModel.completedMissions.isEmpty {
                    Text("No completed missions")
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
    let isCompleted: Bool
    @EnvironmentObject private var themeManager: ThemeManager

    init(mission: Mission, isActive: Bool, isCompleted: Bool = false) {
        self.mission = mission
        self.isActive = isActive
        self.isCompleted = isCompleted
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(mission.name ?? "Untitled Mission")
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(isCompleted ? themeManager.successColor : (isActive ? themeManager.accentColor : themeManager.primaryColor))
                    .fontWeight(.bold)
                    .strikethrough(isCompleted)

                Spacer()

                priorityIndicator
            }

            if let description = mission.missionDescription, !description.isEmpty {
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

struct EditMissionSheet: View {
    @ObservedObject var viewModel: MissionViewModel
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var description = ""
    @State private var priority: Priority = .medium
    @State private var progress: Double = 0

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("EDIT MISSION")
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

                    CodecButton(title: "UPDATE", action: {
                        if let mission = viewModel.missionToEdit {
                            viewModel.updateMission(
                                mission,
                                title: title,
                                description: description,
                                priority: priority,
                                progress: progress
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
            if let mission = viewModel.missionToEdit {
                title = mission.name ?? ""
                description = mission.missionDescription ?? ""
                priority = Priority(rawValue: mission.priority ?? "medium") ?? .medium
                progress = mission.progress
            }
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
    @Published var completedMissions: [Mission] = []
    @Published var currentMission: Mission?
    @Published var showNewMissionDialog = false
    @Published var showEditMissionDialog = false
    @Published var missionToEdit: Mission?

    private let persistenceController = PersistenceController.shared

    override init() {
        super.init()
        fetchMissions()
    }

    func fetchMissions() {
        let context = persistenceController.container.viewContext

        // Fetch active missions (not completed)
        let activeMissionsRequest: NSFetchRequest<Mission> = Mission.fetchRequest()
        activeMissionsRequest.predicate = NSPredicate(format: "status != %@", "completed")
        activeMissionsRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Mission.timestamp, ascending: false)]

        // Fetch completed missions
        let completedMissionsRequest: NSFetchRequest<Mission> = Mission.fetchRequest()
        completedMissionsRequest.predicate = NSPredicate(format: "status == %@", "completed")
        completedMissionsRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Mission.timestamp, ascending: false)]

        do {
            missions = try context.fetch(activeMissionsRequest)
            completedMissions = try context.fetch(completedMissionsRequest)
            currentMission = missions.first(where: { $0.status == "active" })
        } catch {
            print("Error fetching missions: \(error)")
        }
    }

    func createMission(title: String, description: String, priority: Priority, progress: Double) {
        let context = persistenceController.container.viewContext
        let newMission = Mission(context: context)

        newMission.id = UUID()
        newMission.name = title
        newMission.missionDescription = description
        newMission.priority = priority.rawValue
        newMission.progress = progress
        newMission.status = currentMission == nil ? "active" : status(for: newMission, progress: progress)
        newMission.timestamp = Date()

        do {
            try context.save()
            if currentMission == nil {
                currentMission = newMission
            }
            fetchMissions()
        } catch {
            print("Error saving mission: \(error)")
        }
    }

    func setCurrentMission(_ mission: Mission) {
        let context = persistenceController.container.viewContext

        if currentMission?.objectID == mission.objectID {
            return
        }

        if let activeMission = currentMission, activeMission.objectID != mission.objectID {
            if activeMission.progress >= 100.0 {
                activeMission.status = "completed"
            } else {
                activeMission.status = activeMission.progress > 0 ? "in_progress" : "pending"
            }
        }

        currentMission = mission
        mission.status = "active"

        do {
            try context.save()
            fetchMissions()
        } catch {
            print("Error setting current mission: \(error)")
        }
    }

    func editMission(_ mission: Mission) {
        missionToEdit = mission
        showEditMissionDialog = true
    }

    func updateMission(_ mission: Mission, title: String, description: String, priority: Priority, progress: Double) {
        let context = persistenceController.container.viewContext

        mission.name = title
        mission.missionDescription = description
        mission.priority = priority.rawValue
        mission.progress = progress
        mission.status = status(for: mission, progress: progress)

        if mission.status == "completed" && currentMission?.objectID == mission.objectID {
            currentMission = nil
        }

        do {
            try context.save()
            DispatchQueue.main.async {
                self.objectWillChange.send()
                self.fetchMissions()
            }
        } catch {
            print("Error updating mission: \(error)")
        }
    }

    func updateMissionProgress(_ mission: Mission, progress: Double) {
        let context = persistenceController.container.viewContext
        mission.progress = progress

        do {
            try context.save()
            fetchMissions()
        } catch {
            print("Error updating mission progress: \(error)")
        }
    }

    func deleteMission(_ mission: Mission) {
        let context = persistenceController.container.viewContext
        context.delete(mission)

        do {
            try context.save()
            fetchMissions()
            if currentMission == mission {
                currentMission = nil
            }
        } catch {
            print("Error deleting mission: \(error)")
        }
    }

    func reactivateMission(_ mission: Mission) {
        let context = persistenceController.container.viewContext
        mission.status = "pending"
        mission.progress = 0.0

        do {
            try context.save()
            DispatchQueue.main.async {
                self.objectWillChange.send()
                self.fetchMissions()
            }
        } catch {
            print("Error reactivating mission: \(error)")
        }
    }

    private func status(for mission: Mission, progress: Double? = nil) -> String {
        let progressValue = progress ?? mission.progress

        if progressValue >= 100.0 {
            return "completed"
        }

        if currentMission?.objectID == mission.objectID {
            return "active"
        }

        return progressValue > 0 ? "in_progress" : "pending"
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
