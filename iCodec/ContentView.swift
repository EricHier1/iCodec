import SwiftUI
import CoreData

struct ContentView: View {
    @StateObject private var coordinator = AppCoordinator()
    @StateObject private var themeManager = ThemeManager()
    @State private var showBootScreen = true
    @State private var currentTime = Date()
    @State private var showMissionStatsDetail = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            if showBootScreen {
                BootScreen()
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            withAnimation(.easeInOut(duration: 0.5)) {
                                showBootScreen = false
                            }
                        }
                    }
            } else {
                mainInterface
            }
        }
        .environmentObject(coordinator)
        .environmentObject(themeManager)
        .preferredColorScheme(.dark)
        .onReceive(timer) { _ in
            currentTime = Date()
        }
        .sheet(isPresented: $showMissionStatsDetail) {
            MissionStatsDetailView()
        }
    }

    private var horizontalPadding: CGFloat {
        horizontalSizeClass == .compact ? 16 : 16
    }

    private var topPadding: CGFloat {
        horizontalSizeClass == .compact ? 8 : 24
    }

    private var mainInterface: some View {
        GeometryReader { proxy in
            ZStack {
                themeManager.backgroundColor
                    .ignoresSafeArea()

                ScanlineOverlay()
                    .opacity(0.15)

                VStack(spacing: 16) {
                    header
                    navigationMenu
                    contentArea
                    Spacer()
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.top, topPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            // Status bar with time
            HStack {
                Text(DateFormatter.timeFormatter.string(from: currentTime))
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(themeManager.primaryColor)
                    .fontWeight(.bold)

                Spacer()

                // Mission stats counters (compact)
                HStack(spacing: 8) {
                    StatCounter(
                        label: "ACT",
                        value: SharedDataManager.shared.activeMissionCount,
                        color: themeManager.accentColor
                    )

                    StatCounter(
                        label: "TOD",
                        value: SharedDataManager.shared.todayCompletedCount,
                        color: themeManager.successColor
                    )

                    StatCounter(
                        label: "TOT",
                        value: SharedDataManager.shared.totalCompletedCount,
                        color: themeManager.primaryColor
                    )
                    .onTapGesture {
                        showMissionStatsDetail = true
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(themeManager.primaryColor.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(themeManager.primaryColor.opacity(0.3), lineWidth: 1)
                )
                .cornerRadius(4)

                HStack(spacing: 8) {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            coordinator.currentModule = .settings
                        }
                    }) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(themeManager.primaryColor)
                            .padding(6)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(themeManager.primaryColor, lineWidth: 1)
                            )
                    }
                    .accessibilityLabel("Open Settings")

                    // Theme indicator
                    Button(action: {
                        let currentIndex = CodecTheme.allCases.firstIndex(of: themeManager.currentTheme) ?? 0
                        let nextIndex = (currentIndex + 1) % CodecTheme.allCases.count
                        themeManager.switchTheme(to: CodecTheme.allCases[nextIndex])
                    }) {
                        HStack(spacing: 3) {
                            Circle()
                                .fill(themeManager.primaryColor)
                                .frame(width: 6, height: 6)
                            Text(themeManager.currentTheme.name.uppercased())
                                .font(.system(size: 8, design: .monospaced))
                                .foregroundColor(themeManager.primaryColor)
                        }
                    }

                    HStack(spacing: 4) {
                        Circle()
                            .fill(themeManager.successColor)
                            .frame(width: 6, height: 6)

                        Text("ONLINE")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(themeManager.successColor)
                    }
                }
            }

            // App title
            Text("iCODEC")
                .font(.system(size: 24, design: .monospaced))
                .fontWeight(.bold)
                .foregroundColor(themeManager.primaryColor)
                .textCase(.uppercase)
                .shadow(color: themeManager.primaryColor.opacity(0.5), radius: 5)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(themeManager.primaryColor.opacity(0.1))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(themeManager.primaryColor, lineWidth: 1)
        )
        .cornerRadius(8)
    }

    private var navigationMenu: some View {
        HStack(spacing: 8) {
            ForEach(AppModule.navigationModules, id: \.self) { module in
                NavigationItem(
                    module: module,
                    isActive: coordinator.currentModule == module
                ) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        coordinator.currentModule = module
                    }
                }
            }
        }
        .padding(.horizontal, 8)
    }

    private var contentArea: some View {
        VStack {
            switch coordinator.currentModule {
            case .mission:
                MissionView()
            case .map:
                MapView()
            case .intel:
                IntelView()
            case .alerts:
                AlertsView()
            case .audio:
                AudioView()
            case .settings:
                SettingsView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.3), value: coordinator.currentModule)
    }
}

struct NavigationItem: View {
    let module: AppModule
    let isActive: Bool
    let action: () -> Void

    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        Button(action: {
            TacticalSoundPlayer.playNavigation()
            action()
        }) {
            VStack(spacing: 4) {
                // Icon/Glyph
                Text(module.glyph)
                    .font(.system(size: 12, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundColor(isActive ? themeManager.backgroundColor : themeManager.primaryColor)
                    .frame(width: 32, height: 20)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(isActive ? themeManager.primaryColor : Color.clear)
                    )

                // Label
                Text(module.rawValue)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(isActive ? themeManager.accentColor : themeManager.textColor)
                    .fontWeight(isActive ? .bold : .regular)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isActive ? themeManager.primaryColor.opacity(0.1) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isActive ? themeManager.primaryColor : themeManager.primaryColor.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct BootScreen: View {
    @State private var loadingProgress: CGFloat = 0
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 32) {
                // Logo
                VStack(spacing: 16) {
                    // Diamond logo placeholder
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(themeManager.primaryColor, lineWidth: 2)
                            .frame(width: 60, height: 60)

                        Text("◆")
                            .font(.system(size: 32))
                            .foregroundColor(themeManager.primaryColor)
                    }

                    Text("iCODEC")
                        .font(.system(size: 28, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundColor(themeManager.primaryColor)
                        .shadow(color: themeManager.primaryColor.opacity(0.5), radius: 10)
                }

                // Loading section
                VStack(spacing: 16) {
                    // Loading bar
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(themeManager.primaryColor, lineWidth: 1)
                            .frame(height: 8)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(themeManager.primaryColor)
                            .frame(width: 200 * loadingProgress, height: 8)
                    }
                    .frame(width: 200)

                    Text("Initializing tactical interface...")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(themeManager.textColor.opacity(0.8))
                }
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 2.5)) {
                    loadingProgress = 1.0
                }
            }
        }
    }
}

struct StatCounter: View {
    let label: String
    let value: Int
    let color: Color
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        VStack(spacing: 1) {
            Text("\(value)")
                .font(.system(size: 10, design: .monospaced))
                .fontWeight(.bold)
                .foregroundColor(color)

            Text(label)
                .font(.system(size: 7, design: .monospaced))
                .foregroundColor(themeManager.textColor.opacity(0.7))
        }
        .frame(minWidth: 28)
    }
}

struct MissionStatsDetailView: View {
    @ObservedObject private var sharedData = SharedDataManager.shared
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTimeframe: TimeFrame = .week

    enum TimeFrame: String, CaseIterable {
        case day = "Day"
        case week = "Week"
        case month = "Month"
        case all = "All Time"
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                Text("MISSION STATISTICS")
                    .font(.system(size: 18, design: .monospaced))
                    .foregroundColor(themeManager.primaryColor)
                    .fontWeight(.bold)

                // Time frame selector
                Picker("Time Frame", selection: $selectedTimeframe) {
                    ForEach(TimeFrame.allCases, id: \.self) { timeframe in
                        Text(timeframe.rawValue.uppercased())
                            .tag(timeframe)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .background(themeManager.surfaceColor.opacity(0.2))

                // Stats grid
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 2), spacing: 16) {
                    MissionStatCard(
                        title: "COMPLETED",
                        value: completedMissionsForTimeframe,
                        subtitle: "missions",
                        color: themeManager.successColor
                    )

                    MissionStatCard(
                        title: "ACTIVE",
                        value: sharedData.activeMissionCount,
                        subtitle: "ongoing",
                        color: themeManager.accentColor
                    )

                    MissionStatCard(
                        title: "SUCCESS RATE",
                        value: successRate,
                        subtitle: "%",
                        color: themeManager.primaryColor
                    )

                    MissionStatCard(
                        title: "AVG COMPLETION",
                        value: averageCompletionTime,
                        subtitle: "days",
                        color: themeManager.warningColor
                    )
                }

                // Timeline chart placeholder
                VStack(alignment: .leading, spacing: 12) {
                    Text("COMPLETION TIMELINE")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(themeManager.accentColor)
                        .fontWeight(.bold)

                    MissionTimelineChart(timeframe: selectedTimeframe)
                        .frame(height: 120)
                }
                .padding()
                .background(themeManager.surfaceColor.opacity(0.2))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(themeManager.primaryColor.opacity(0.3), lineWidth: 1)
                )
                .cornerRadius(8)

                Spacer()

                // Close button
                CodecButton(title: "CLOSE", action: {
                    dismiss()
                }, style: .secondary, size: .fullWidth)
            }
            .padding(20)
            .background(themeManager.backgroundColor)
        }
    }

    private var completedMissionsForTimeframe: Int {
        let calendar = Calendar.current
        let now = Date()
        let startDate: Date

        switch selectedTimeframe {
        case .day:
            startDate = calendar.startOfDay(for: now)
        case .week:
            startDate = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        case .month:
            startDate = calendar.dateInterval(of: .month, for: now)?.start ?? now
        case .all:
            return sharedData.totalCompletedCount
        }

        return sharedData.missionViewModel.completedMissions.filter { mission in
            guard let timestamp = mission.timestamp else { return false }
            return timestamp >= startDate && mission.status == "completed"
        }.count
    }

    private var successRate: Int {
        let completed = completedMissionsForTimeframe
        let total = completed + sharedData.activeMissionCount
        return total > 0 ? Int((Double(completed) / Double(total)) * 100) : 0
    }

    private var averageCompletionTime: Int {
        let completedMissions = sharedData.missionViewModel.completedMissions
        guard !completedMissions.isEmpty else { return 0 }

        let totalDays = completedMissions.compactMap { mission -> Int? in
            guard let timestamp = mission.timestamp else { return nil }
            let days = Calendar.current.dateComponents([.day], from: timestamp, to: Date()).day ?? 0
            return max(1, days)
        }.reduce(0, +)

        return totalDays / completedMissions.count
    }
}

struct MissionStatCard: View {
    let title: String
    let value: Int
    let subtitle: String
    let color: Color
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(themeManager.textColor.opacity(0.7))
                .fontWeight(.semibold)

            Text("\(value)")
                .font(.system(size: 24, design: .monospaced))
                .foregroundColor(color)
                .fontWeight(.bold)

            Text(subtitle)
                .font(.system(size: 8, design: .monospaced))
                .foregroundColor(themeManager.textColor.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(8)
    }
}

struct MissionTimelineChart: View {
    let timeframe: MissionStatsDetailView.TimeFrame
    @ObservedObject private var sharedData = SharedDataManager.shared
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        GeometryReader { geometry in
            let data = getChartData()
            let maxValue = data.map(\.value).max() ?? 1

            HStack(alignment: .bottom, spacing: 4) {
                ForEach(Array(data.enumerated()), id: \.offset) { index, point in
                    VStack(spacing: 4) {
                        Spacer()

                        // Bar
                        RoundedRectangle(cornerRadius: 2)
                            .fill(themeManager.primaryColor.opacity(0.7))
                            .frame(
                                width: (geometry.size.width - CGFloat(data.count - 1) * 4) / CGFloat(data.count),
                                height: max(2, CGFloat(point.value) / CGFloat(maxValue) * (geometry.size.height - 20))
                            )

                        // Label
                        Text(point.label)
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundColor(themeManager.textColor.opacity(0.6))
                    }
                }
            }
        }
    }

    private func getChartData() -> [(label: String, value: Int)] {
        let calendar = Calendar.current
        let now = Date()

        switch timeframe {
        case .day:
            return (0..<7).reversed().map { daysAgo in
                let date = calendar.date(byAdding: .day, value: -daysAgo, to: now) ?? now
                let dayStart = calendar.startOfDay(for: date)
                let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart

                let count = sharedData.missionViewModel.completedMissions.filter { mission in
                    guard let timestamp = mission.timestamp else { return false }
                    return timestamp >= dayStart && timestamp < dayEnd && mission.status == "completed"
                }.count

                let formatter = DateFormatter()
                formatter.dateFormat = "MM/dd"
                return (label: formatter.string(from: date), value: count)
            }

        case .week:
            return (0..<4).reversed().map { weeksAgo in
                let date = calendar.date(byAdding: .weekOfYear, value: -weeksAgo, to: now) ?? now
                let weekInterval = calendar.dateInterval(of: .weekOfYear, for: date)

                let count = sharedData.missionViewModel.completedMissions.filter { mission in
                    guard let timestamp = mission.timestamp,
                          let interval = weekInterval else { return false }
                    return interval.contains(timestamp) && mission.status == "completed"
                }.count

                return (label: "W\(weeksAgo == 0 ? "" : "-\(weeksAgo)")", value: count)
            }

        case .month:
            return (0..<6).reversed().map { monthsAgo in
                let date = calendar.date(byAdding: .month, value: -monthsAgo, to: now) ?? now
                let monthInterval = calendar.dateInterval(of: .month, for: date)

                let count = sharedData.missionViewModel.completedMissions.filter { mission in
                    guard let timestamp = mission.timestamp,
                          let interval = monthInterval else { return false }
                    return interval.contains(timestamp) && mission.status == "completed"
                }.count

                let formatter = DateFormatter()
                formatter.dateFormat = "MMM"
                return (label: formatter.string(from: date), value: count)
            }

        case .all:
            return (0..<12).reversed().map { monthsAgo in
                let date = calendar.date(byAdding: .month, value: -monthsAgo, to: now) ?? now
                let monthInterval = calendar.dateInterval(of: .month, for: date)

                let count = sharedData.missionViewModel.completedMissions.filter { mission in
                    guard let timestamp = mission.timestamp,
                          let interval = monthInterval else { return false }
                    return interval.contains(timestamp) && mission.status == "completed"
                }.count

                let formatter = DateFormatter()
                formatter.dateFormat = "MMM"
                return (label: formatter.string(from: date), value: count)
            }
        }
    }
}

extension DateFormatter {
    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}
