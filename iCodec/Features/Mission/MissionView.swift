import SwiftUI
import CoreData
import CoreLocation

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
        .sheet(isPresented: $viewModel.showMissionDetailDialog) {
            if let mission = viewModel.missionToView {
                MissionDetailView(mission: mission, viewModel: viewModel)
            }
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
                    .onTapGesture {
                        viewModel.viewMissionDetail(currentMission)
                    }
                    .contextMenu {
                        Button("View Details", systemImage: "eye") {
                            viewModel.viewMissionDetail(currentMission)
                        }

                        Button("Edit Mission", systemImage: "pencil") {
                            viewModel.editMission(currentMission)
                        }

                        Button("Mark Complete", systemImage: "checkmark.circle") {
                            viewModel.completeMission(currentMission)
                        }

                        Button("Delete Mission", systemImage: "trash", role: .destructive) {
                            viewModel.deleteMission(currentMission)
                        }
                    }

                ActiveMissionControls(mission: currentMission, viewModel: viewModel)
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
                            viewModel.viewMissionDetail(mission)
                        }
                        .onLongPressGesture {
                            viewModel.setCurrentMission(mission)
                        }
                        .contextMenu {
                            Button("View Details", systemImage: "eye") {
                                viewModel.viewMissionDetail(mission)
                            }
                            Button("Set as Active", systemImage: "play.circle") {
                                viewModel.setCurrentMission(mission)
                            }
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
                        .onTapGesture {
                            viewModel.viewMissionDetail(mission)
                        }
                        .contextMenu {
                            Button("View Details", systemImage: "eye") {
                                viewModel.viewMissionDetail(mission)
                            }
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
    @ObservedObject private var mission: Mission
    let isActive: Bool
    let isCompleted: Bool
    @EnvironmentObject private var themeManager: ThemeManager

    init(mission: Mission, isActive: Bool, isCompleted: Bool = false) {
        self._mission = ObservedObject(wrappedValue: mission)
        self.isActive = isActive
        self.isCompleted = isCompleted
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with title and priority
            HStack(alignment: .top, spacing: 8) {
                // Mission icon
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "target")
                    .font(.system(size: 20))
                    .foregroundColor(isCompleted ? themeManager.successColor : (isActive ? themeManager.accentColor : themeManager.primaryColor))

                VStack(alignment: .leading, spacing: 4) {
                    // Title - Larger and more prominent
                    Text(mission.name ?? "Untitled Mission")
                        .font(.system(size: 16, design: .monospaced))
                        .foregroundColor(isCompleted ? themeManager.successColor : (isActive ? themeManager.accentColor : themeManager.primaryColor))
                        .fontWeight(.bold)
                        .strikethrough(isCompleted)

                    // Waypoint location with distance if available
                    if let waypointName = mission.waypointName, !waypointName.isEmpty,
                       let waypointId = mission.waypointId {
                        HStack(spacing: 6) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(themeManager.accentColor)

                            Text("\(waypointName) (\(waypointId))")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(themeManager.accentColor)

                            if let distance = calculateWaypointDistance() {
                                Text("•")
                                    .foregroundColor(themeManager.textColor.opacity(0.5))
                                Text(distance)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(themeManager.warningColor)
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                }

                Spacer()

                // Priority badge - Larger and more visible
                priorityIndicator
            }

            // Progress bar - Bigger and more prominent
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("PROGRESS")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(themeManager.textColor.opacity(0.7))
                        .fontWeight(.semibold)

                    Spacer()

                    Text("\(Int(mission.progress))%")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(progressColor)
                        .fontWeight(.bold)
                }

                // Enhanced progress bar with segments
                GeometryReader { geometry in
                    let fraction = max(0, min(1, mission.progress / 100))
                    let width = max(CGFloat(fraction) * geometry.size.width, 2)
                    ZStack(alignment: .leading) {
                        // Background with grid pattern
                        RoundedRectangle(cornerRadius: 4)
                            .fill(themeManager.surfaceColor.opacity(0.5))

                        // Progress fill with gradient
                        RoundedRectangle(cornerRadius: 4)
                            .fill(progressColor)
                            .frame(width: width)

                        // Segment markers
                        HStack(spacing: 0) {
                            ForEach(0..<4) { index in
                                Rectangle()
                                    .fill(themeManager.backgroundColor.opacity(0.3))
                                    .frame(width: 1)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                }
                .frame(height: 8)
            }

            // Action buttons for active missions
            if isActive && !isCompleted {
                HStack(spacing: 8) {
                    if mission.waypointId != nil {
                        actionButton(title: "NAVIGATE", icon: "location.fill", action: {
                            // TODO: Navigate to waypoint
                        })
                    }

                    actionButton(title: "DETAILS", icon: "info.circle.fill", action: {
                        // Handled by parent tap gesture
                    })

                    Spacer()
                }
            }
        }
        .padding(14)
        .background(
            ZStack {
                // Base background
                (isActive ? themeManager.primaryColor.opacity(0.15) : themeManager.surfaceColor.opacity(0.25))

                // Subtle corner accent
                if isActive {
                    VStack {
                        HStack {
                            Rectangle()
                                .fill(themeManager.primaryColor.opacity(0.4))
                                .frame(width: 40, height: 2)
                            Spacer()
                        }
                        Spacer()
                    }
                }
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isActive ? themeManager.primaryColor : themeManager.primaryColor.opacity(0.3), lineWidth: isActive ? 2 : 1)
        )
        .cornerRadius(10)
    }

    private func actionButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(title)
                    .font(.system(size: 10, design: .monospaced))
                    .fontWeight(.semibold)
            }
            .foregroundColor(themeManager.primaryColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(themeManager.primaryColor.opacity(0.15))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(themeManager.primaryColor, lineWidth: 1)
            )
            .cornerRadius(4)
        }
    }

    private func calculateWaypointDistance() -> String? {
        guard let userCoordinate = SharedDataManager.shared.mapViewModel.userLocation,
              mission.latitude != 0 && mission.longitude != 0 else {
            return nil
        }

        let userLocation = CLLocation(latitude: userCoordinate.latitude, longitude: userCoordinate.longitude)
        let waypointLocation = CLLocation(latitude: mission.latitude, longitude: mission.longitude)
        let distance = userLocation.distance(from: waypointLocation)

        if distance < 1000 {
            return String(format: "%.0f m", distance)
        } else {
            return String(format: "%.1f km", distance / 1000)
        }
    }

    private var priorityIndicator: some View {
        let priority = Priority(rawValue: mission.priority ?? "medium") ?? .medium
        return HStack(spacing: 4) {
            // Priority icon
            Circle()
                .fill(priority.color)
                .frame(width: 8, height: 8)

            Text(priority.rawValue.uppercased())
                .font(.system(size: 10, design: .monospaced))
                .fontWeight(.bold)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(priority.color.opacity(0.2))
        .foregroundColor(priority.color)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(priority.color, lineWidth: 1.5)
        )
        .cornerRadius(6)
    }

    private var progressColor: Color {
        let progress = mission.progress
        if progress < 25 { return themeManager.errorColor }
        else if progress < 75 { return themeManager.warningColor }
        else { return themeManager.successColor }
    }
}

struct ActiveMissionControls: View {
    @ObservedObject var mission: Mission
    let viewModel: MissionViewModel
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var progressValue: Double = 0
    var body: some View {
        VStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Mission Progress")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(themeManager.textColor)

                HStack(spacing: 12) {
                    Slider(value: $progressValue, in: 0...100, step: 5) {
                        Text("Progress")
                    }
                    .tint(themeManager.primaryColor)
                    .onChange(of: progressValue) { _, newValue in
                        let previous = mission.progress
                        guard abs(previous - newValue) >= 1 else { return }
                        mission.progress = newValue
                        viewModel.updateMissionProgress(mission, progress: newValue)
                    }

                    Text("\(Int(progressValue))%")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(themeManager.primaryColor)
                        .frame(width: 44)
                }
            }

            HStack(spacing: 12) {
                CodecButton(title: "EDIT DETAILS", action: {
                    TacticalSoundPlayer.playNavigation()
                    viewModel.editMission(mission)
                }, style: .secondary, size: .small)

                CodecButton(title: "MARK COMPLETE", action: {
                    TacticalSoundPlayer.playAction()
                    viewModel.completeMission(mission)
                }, style: .primary, size: .small)

                Spacer()
            }
        }
        .padding(12)
        .background(themeManager.surfaceColor.opacity(0.25))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(themeManager.primaryColor.opacity(0.35), lineWidth: 1)
        )
        .cornerRadius(8)
        .onAppear {
            progressValue = mission.progress
        }
        .onChange(of: mission.progress) { _, newValue in
            if progressValue != newValue {
                progressValue = newValue
            }
        }
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
    @State private var selectedWaypointId: String?

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Compact header
                HStack {
                    CodecButton(title: "CANCEL", action: {
                        dismiss()
                    }, style: .secondary, size: .small)

                    Spacer()

                    Text("NEW MISSION")
                        .font(.system(size: 16, design: .monospaced))
                        .foregroundColor(themeManager.primaryColor)
                        .fontWeight(.bold)

                    Spacer()

                    CodecButton(title: "CREATE", action: {
                        if viewModel.createMission(
                            title: title,
                            description: description,
                            priority: priority,
                            progress: progress,
                            waypointId: selectedWaypointId
                        ) {
                            dismiss()
                        }
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

                // Full screen content area
                ScrollView {
                    VStack(spacing: 16) {
                        // Mission title
                        VStack(alignment: .leading, spacing: 4) {
                            Text("MISSION TITLE")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(themeManager.textColor.opacity(0.7))
                                .fontWeight(.bold)

                            TextField("Enter mission title...", text: $title)
                                .textFieldStyle(CodecTextFieldStyle())
                        }

                        // Waypoint assignment
                        VStack(alignment: .leading, spacing: 4) {
                            Text("MISSION LOCATION")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(themeManager.textColor.opacity(0.7))
                                .fontWeight(.bold)

                            Picker("Waypoint", selection: $selectedWaypointId) {
                                Text("No waypoint assigned").tag(nil as String?)
                                ForEach(SharedDataManager.shared.mapViewModel.waypoints) { waypoint in
                                    Text("\(waypoint.name) (\(waypoint.id))").tag(waypoint.id as String?)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(themeManager.surfaceColor.opacity(0.3))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(themeManager.primaryColor.opacity(0.5), lineWidth: 1)
                            )
                            .cornerRadius(8)
                        }

                        // Priority and progress
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("PRIORITY LEVEL")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(themeManager.textColor.opacity(0.7))
                                    .fontWeight(.bold)

                                Picker("Priority", selection: $priority) {
                                    ForEach(Priority.allCases, id: \.self) { priority in
                                        Text(priority.rawValue.uppercased())
                                            .tag(priority)
                                    }
                                }
                                .pickerStyle(SegmentedPickerStyle())
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("PROGRESS: \(Int(progress))%")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(themeManager.textColor.opacity(0.7))
                                    .fontWeight(.bold)

                                Slider(value: $progress, in: 0...100, step: 5)
                                    .accentColor(themeManager.primaryColor)
                            }
                        }

                        // Error display
                        if let error = viewModel.missionError {
                            HStack {
                                Text(error)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(.red)
                                    .multilineTextAlignment(.leading)
                                Spacer()
                            }
                            .padding(.horizontal, 4)
                        }

                        // Main mission description area (takes most of the screen)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("MISSION OBJECTIVES & DETAILS")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(themeManager.textColor.opacity(0.7))
                                .fontWeight(.bold)

                            TextField("Enter detailed mission objectives...\n\nInclude:\n• Primary objectives\n• Secondary objectives\n• Rules of engagement\n• Success criteria\n• Risk assessment\n• Required resources\n• Timeline and milestones", text: $description, axis: .vertical)
                                .textFieldStyle(CodecTextFieldStyle())
                                .lineLimit(15...50)
                                .frame(minHeight: geometry.size.height * 0.55)
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
}

struct MissionDetailView: View {
    @ObservedObject var mission: Mission
    let viewModel: MissionViewModel
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Compact header
                HStack {
                    CodecButton(title: "CLOSE", action: {
                        dismiss()
                    }, style: .secondary, size: .small)

                    Spacer()

                    Text("MISSION DETAILS")
                        .font(.system(size: 16, design: .monospaced))
                        .foregroundColor(themeManager.primaryColor)
                        .fontWeight(.bold)

                    Spacer()

                    CodecButton(title: "EDIT", action: {
                        dismiss()
                        viewModel.editMission(mission)
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

                // Full screen content area
                ScrollView {
                    VStack(spacing: 24) {
                        // Mission title and status
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text(mission.name ?? "Untitled Mission")
                                    .font(.system(size: 20, design: .monospaced))
                                    .foregroundColor(themeManager.primaryColor)
                                    .fontWeight(.bold)

                                Spacer()

                                priorityIndicator
                            }

                            HStack {
                                statusIndicator
                                Spacer()
                                if let timestamp = mission.timestamp {
                                    Text("CREATED: \(DateFormatter.missionDateFormatter.string(from: timestamp))")
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(themeManager.textColor.opacity(0.7))
                                }
                            }
                        }

                        // Progress section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("MISSION PROGRESS")
                                .font(.system(size: 14, design: .monospaced))
                                .foregroundColor(themeManager.accentColor)
                                .fontWeight(.bold)

                            VStack(spacing: 8) {
                                HStack {
                                    Text("\(Int(mission.progress))% COMPLETE")
                                        .font(.system(size: 16, design: .monospaced))
                                        .foregroundColor(themeManager.primaryColor)
                                        .fontWeight(.bold)
                                    Spacer()
                                }

                                GeometryReader { progressGeometry in
                                    let fraction = max(0, min(1, mission.progress / 100))
                                    let width = max(CGFloat(fraction) * progressGeometry.size.width, 2)
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(themeManager.surfaceColor)

                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(progressColor)
                                            .frame(width: width)
                                    }
                                }
                                .frame(height: 8)
                            }
                        }

                        // Mission description
                        VStack(alignment: .leading, spacing: 12) {
                            Text("MISSION OBJECTIVES & DETAILS")
                                .font(.system(size: 14, design: .monospaced))
                                .foregroundColor(themeManager.accentColor)
                                .fontWeight(.bold)

                            if let description = mission.missionDescription, !description.isEmpty {
                                Text(description)
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
                            } else {
                                Text("No mission description provided")
                                    .font(.system(size: 14, design: .monospaced))
                                    .foregroundColor(themeManager.textColor.opacity(0.6))
                                    .italic()
                            }
                        }

                        // Action buttons (if not completed)
                        if mission.status != "completed" {
                            VStack(spacing: 12) {
                                Text("MISSION ACTIONS")
                                    .font(.system(size: 14, design: .monospaced))
                                    .foregroundColor(themeManager.accentColor)
                                    .fontWeight(.bold)

                                VStack(spacing: 8) {
                                    if viewModel.currentMission?.objectID != mission.objectID {
                                        CodecButton(title: "SET AS ACTIVE MISSION", action: {
                                            viewModel.setCurrentMission(mission)
                                        }, style: .primary, size: .fullWidth)
                                    }

                                    HStack(spacing: 12) {
                                        CodecButton(title: "EDIT MISSION", action: {
                                            dismiss()
                                            viewModel.editMission(mission)
                                        }, style: .secondary, size: .fullWidth)

                                        if mission.progress < 100 {
                                            CodecButton(title: "MARK COMPLETE", action: {
                                                viewModel.completeMission(mission)
                                                dismiss()
                                            }, style: .primary, size: .fullWidth)
                                        }
                                    }
                                }
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
        let priority = Priority(rawValue: mission.priority ?? "medium") ?? .medium
        return Text(priority.rawValue.uppercased())
            .font(.system(size: 10, design: .monospaced))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(priority.color.opacity(0.2))
            .foregroundColor(priority.color)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(priority.color, lineWidth: 1)
            )
            .cornerRadius(6)
    }

    private var statusIndicator: some View {
        let status = mission.status ?? "pending"
        let statusColor = statusColor(for: status)
        return Text(status.uppercased())
            .font(.system(size: 10, design: .monospaced))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.2))
            .foregroundColor(statusColor)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(statusColor, lineWidth: 1)
            )
            .cornerRadius(6)
    }

    private var progressColor: Color {
        let progress = mission.progress
        if progress < 25 { return themeManager.errorColor }
        else if progress < 75 { return themeManager.warningColor }
        else { return themeManager.successColor }
    }

    private func statusColor(for status: String) -> Color {
        switch status {
        case "active": return themeManager.accentColor
        case "completed": return themeManager.successColor
        case "in_progress": return themeManager.warningColor
        default: return themeManager.textColor.opacity(0.7)
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
    @State private var selectedWaypointId: String?

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Compact header
                HStack {
                    CodecButton(title: "CANCEL", action: {
                        dismiss()
                    }, style: .secondary, size: .small)

                    Spacer()

                    Text("EDIT MISSION")
                        .font(.system(size: 16, design: .monospaced))
                        .foregroundColor(themeManager.primaryColor)
                        .fontWeight(.bold)

                    Spacer()

                    CodecButton(title: "UPDATE", action: {
                        if let mission = viewModel.missionToEdit {
                            viewModel.updateMission(
                                mission,
                                title: title,
                                description: description,
                                priority: priority,
                                progress: progress,
                                waypointId: selectedWaypointId
                            )
                        }
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

                // Full screen content area
                ScrollView {
                    VStack(spacing: 16) {
                        // Mission title
                        VStack(alignment: .leading, spacing: 4) {
                            Text("MISSION TITLE")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(themeManager.textColor.opacity(0.7))
                                .fontWeight(.bold)

                            TextField("Enter mission title...", text: $title)
                                .textFieldStyle(CodecTextFieldStyle())
                        }

                        // Waypoint assignment
                        VStack(alignment: .leading, spacing: 4) {
                            Text("MISSION LOCATION")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(themeManager.textColor.opacity(0.7))
                                .fontWeight(.bold)

                            Picker("Waypoint", selection: $selectedWaypointId) {
                                Text("No waypoint assigned").tag(nil as String?)
                                ForEach(SharedDataManager.shared.mapViewModel.waypoints) { waypoint in
                                    Text("\(waypoint.name) (\(waypoint.id))").tag(waypoint.id as String?)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(themeManager.surfaceColor.opacity(0.3))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(themeManager.primaryColor.opacity(0.5), lineWidth: 1)
                            )
                            .cornerRadius(8)
                        }

                        // Priority and progress
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("PRIORITY LEVEL")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(themeManager.textColor.opacity(0.7))
                                    .fontWeight(.bold)

                                Picker("Priority", selection: $priority) {
                                    ForEach(Priority.allCases, id: \.self) { priority in
                                        Text(priority.rawValue.uppercased())
                                            .tag(priority)
                                    }
                                }
                                .pickerStyle(SegmentedPickerStyle())
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("PROGRESS: \(Int(progress))%")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(themeManager.textColor.opacity(0.7))
                                    .fontWeight(.bold)

                                Slider(value: $progress, in: 0...100, step: 5)
                                    .accentColor(themeManager.primaryColor)
                            }
                        }

                        // Main mission description area (takes most of the screen)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("MISSION OBJECTIVES & DETAILS")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(themeManager.textColor.opacity(0.7))
                                .fontWeight(.bold)

                            TextField("Enter detailed mission objectives...\n\nInclude:\n• Primary objectives\n• Secondary objectives\n• Rules of engagement\n• Success criteria\n• Risk assessment\n• Required resources\n• Timeline and milestones", text: $description, axis: .vertical)
                                .textFieldStyle(CodecTextFieldStyle())
                                .lineLimit(15...50)
                                .frame(minHeight: geometry.size.height * 0.55)
                        }

                        Spacer(minLength: 20)
                    }
                    .padding(16)
                }
            }
            .background(themeManager.backgroundColor)
            .navigationBarHidden(true)
        }
        .onAppear {
            if let mission = viewModel.missionToEdit {
                title = mission.name ?? ""
                description = mission.missionDescription ?? ""
                priority = Priority(rawValue: mission.priority ?? "medium") ?? .medium
                progress = mission.progress
                selectedWaypointId = mission.waypointId
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
    @Published var showMissionDetailDialog = false
    @Published var missionToEdit: Mission?
    @Published var missionToView: Mission?
    @Published var missionError: String?

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

    func createMission(title: String, description: String, priority: Priority, progress: Double, waypointId: String? = nil) -> Bool {
        missionError = nil

        // Validate input
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedTitle.isEmpty else {
            missionError = "Mission title is required"
            return false
        }

        guard trimmedTitle.count <= 100 else {
            missionError = "Mission title must be 100 characters or less"
            return false
        }

        guard !trimmedDescription.isEmpty else {
            missionError = "Mission description is required"
            return false
        }

        guard trimmedDescription.count <= 500 else {
            missionError = "Mission description must be 500 characters or less"
            return false
        }

        // Check for duplicate mission titles
        if missions.contains(where: { $0.name?.lowercased() == trimmedTitle.lowercased() }) {
            missionError = "A mission with this title already exists"
            return false
        }

        let context = persistenceController.container.viewContext
        let newMission = Mission(context: context)

        newMission.id = UUID()
        newMission.name = trimmedTitle
        newMission.missionDescription = trimmedDescription
        newMission.priority = priority.rawValue
        newMission.progress = progress
        newMission.status = currentMission == nil ? "active" : status(for: newMission, progress: progress)
        newMission.timestamp = Date()

        // Set waypoint if provided
        if let waypointId = waypointId {
            if let waypoint = SharedDataManager.shared.mapViewModel.waypoints.first(where: { $0.id == waypointId }) {
                newMission.waypointId = waypoint.id
                newMission.waypointName = waypoint.name
                newMission.latitude = waypoint.coordinate.latitude
                newMission.longitude = waypoint.coordinate.longitude
            }
        }

        do {
            try context.save()
            if currentMission == nil {
                currentMission = newMission
            }
            fetchMissions()
            return true
        } catch {
            missionError = "Failed to save mission: \(error.localizedDescription)"
            return false
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

    func viewMissionDetail(_ mission: Mission) {
        missionToView = mission
        showMissionDetailDialog = true
    }

    func updateMission(_ mission: Mission, title: String, description: String, priority: Priority, progress: Double, waypointId: String? = nil) {
        let context = persistenceController.container.viewContext

        mission.name = title
        mission.missionDescription = description
        mission.priority = priority.rawValue
        mission.progress = progress
        mission.status = status(for: mission, progress: progress)

        // Update waypoint if provided
        if let waypointId = waypointId {
            if let waypoint = SharedDataManager.shared.mapViewModel.waypoints.first(where: { $0.id == waypointId }) {
                mission.waypointId = waypoint.id
                mission.waypointName = waypoint.name
                mission.latitude = waypoint.coordinate.latitude
                mission.longitude = waypoint.coordinate.longitude
            }
        } else {
            // Clear waypoint assignment
            mission.waypointId = nil
            mission.waypointName = nil
            mission.latitude = 0
            mission.longitude = 0
        }

        if mission.status == "completed" && currentMission?.objectID == mission.objectID {
            currentMission = nil
        }

        do {
            try context.save()
            fetchMissions()
        } catch {
            print("Error updating mission: \(error)")
        }
    }

    func updateMissionProgress(_ mission: Mission, progress: Double) {
        let context = persistenceController.container.viewContext
        mission.progress = progress
        mission.status = status(for: mission, progress: progress)

        if mission.status == "completed" && currentMission?.objectID == mission.objectID {
            currentMission = nil
        }

        do {
            try context.save()
            fetchMissions()
        } catch {
            print("Error updating mission progress: \(error)")
        }
    }

    func completeMission(_ mission: Mission) {
        updateMissionProgress(mission, progress: 100)
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
            fetchMissions()
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

extension DateFormatter {
    static let missionDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM dd, yyyy HH:mm"
        return formatter
    }()
}
