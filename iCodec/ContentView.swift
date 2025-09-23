import SwiftUI
import CoreData
import CoreLocation
import CoreMotion

struct ContentView: View {
    @StateObject private var coordinator = AppCoordinator()
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var codecAlertManager = CodecAlertManager.shared
    @State private var showBootScreen = true
    @State private var currentTime = Date()
    @State private var showMissionStatsDetail = false
    @State private var autoScrollTimer: Timer?
    @State private var scrollAction: ((AppModule) -> Void)?
    @State private var lastUserInteraction = Date()
    @State private var isUserActive = false
    @State private var currentScrollIndex: Int = 0
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            if showBootScreen {
                BootScreen()
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                            withAnimation(.easeInOut(duration: 0.8)) {
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
                .environmentObject(themeManager)
        }
        .overlay {
            // Codec Alert Overlay
            if codecAlertManager.isShowingAlert, let alert = codecAlertManager.currentAlert {
                CodecAlertView(alert: alert) {
                    codecAlertManager.dismissAlert()
                }
                .environmentObject(themeManager)
                .zIndex(1000)
            }
        }
        .onAppear {
            // Clear badge when app becomes active
            codecAlertManager.clearBadge()
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
                        .onTapGesture {
                            onUserInteraction()
                        }
                    Spacer()
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.top, topPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                // Codec Alert Overlay
                if codecAlertManager.isShowingAlert,
                   let alert = codecAlertManager.currentAlert {
                    CodecAlertView(alert: alert) {
                        codecAlertManager.dismissAlert()
                    }
                    .zIndex(1000)
                }
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
                    Button(action: {
                        print("Active missions counter tapped!")
                        TacticalSoundPlayer.playNavigation()
                        showMissionStatsDetail = true
                    }) {
                        StatCounter(
                            label: "ACT",
                            value: SharedDataManager.shared.activeMissionCount,
                            color: themeManager.accentColor,
                            isInteractive: true
                        )
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: {
                        print("Today missions counter tapped!")
                        TacticalSoundPlayer.playNavigation()
                        showMissionStatsDetail = true
                    }) {
                        StatCounter(
                            label: "TOD",
                            value: SharedDataManager.shared.todayCompletedCount,
                            color: themeManager.successColor,
                            isInteractive: true
                        )
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: {
                        print("Total missions counter tapped!")
                        TacticalSoundPlayer.playNavigation()
                        showMissionStatsDetail = true
                    }) {
                        StatCounter(
                            label: "TOT",
                            value: SharedDataManager.shared.totalCompletedCount,
                            color: themeManager.primaryColor,
                            isInteractive: true
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
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
        ScrollViewReader { scrollProxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(AppModule.navigationModules, id: \.self) { module in
                        NavigationItem(
                            module: module,
                            isActive: coordinator.currentModule == module
                        ) {
                            onUserInteraction()
                            withAnimation(.easeInOut(duration: 0.3)) {
                                coordinator.currentModule = module
                            }
                        }
                        .frame(minWidth: 80)
                        .id(module)
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, 8)
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollIndicators(.hidden)
            .onAppear {
                scrollAction = { module in
                    scrollProxy.scrollTo(module, anchor: .center)
                }
                startAutoScroll()
            }
            .onTapGesture {
                onUserInteraction()
            }
            .onDisappear {
                stopAutoScroll()
            }
        }
    }

    private var contentArea: some View {
        VStack {
            switch coordinator.currentModule {
            case .mission:
                MissionView()
            case .map:
                MapView()
            case .compass:
                Text("COMPASS MODULE")
                    .font(.system(size: 16, design: .monospaced))
                    .foregroundColor(themeManager.primaryColor)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(themeManager.backgroundColor)
            case .audio:
                AudioView()
            case .intel:
                IntelView()
            case .alerts:
                AlertsView()
            case .camera:
                CameraView()
            case .settings:
                SettingsView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.3), value: coordinator.currentModule)
    }

    private func startAutoScroll() {
        stopAutoScroll()

        autoScrollTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { _ in
            Task { @MainActor in
                // Only scroll if user hasn't been active in the last 5 seconds
                let timeSinceLastInteraction = Date().timeIntervalSince(lastUserInteraction)
                guard timeSinceLastInteraction > 5.0 else { return }

                let modules = AppModule.navigationModules
                guard !modules.isEmpty else { return }

                // Move to next module in circular sequence (always left)
                currentScrollIndex = (currentScrollIndex + 1) % modules.count
                let moduleToScrollTo = modules[currentScrollIndex]

                // Consistent linear movement to the left
                withAnimation(.linear(duration: 2.0)) {
                    scrollAction?(moduleToScrollTo)
                }
            }
        }
    }

    private func stopAutoScroll() {
        autoScrollTimer?.invalidate()
        autoScrollTimer = nil
    }

    private func onUserInteraction() {
        lastUserInteraction = Date()
        isUserActive = true

        // Reset user activity after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 8.0) {
            isUserActive = false
        }
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
    @State private var scanlinePosition: CGFloat = 0
    @State private var systemMessages: [String] = []
    @State private var currentMessageIndex = 0
    @State private var logoOpacity: Double = 0
    @State private var gridOpacity: Double = 0
    @EnvironmentObject private var themeManager: ThemeManager

    private let bootMessages = [
        "SYSTEM INITIALIZATION...",
        "LOADING TACTICAL OS v2.1.4",
        "CODEC INTERFACE ONLINE",
        "MISSION CONTROL READY",
        "STEALTH MODULE ACTIVE",
        "SURVEILLANCE NET CONNECTED",
        "AUTHORIZATION VERIFIED",
        "READY FOR OPERATION"
    ]

    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()

            // Grid pattern overlay
            TacticalGrid()
                .opacity(gridOpacity)

            // Scanline effect
            Rectangle()
                .fill(LinearGradient(
                    colors: [Color.clear, themeManager.primaryColor.opacity(0.6), Color.clear],
                    startPoint: .top,
                    endPoint: .bottom
                ))
                .frame(height: 2)
                .offset(y: scanlinePosition)
                .blendMode(.screen)

            VStack(spacing: 40) {
                Spacer()

                // Logo section
                VStack(spacing: 20) {
                    // Tactical diamond logo
                    ZStack {
                        // Outer ring
                        Circle()
                            .stroke(themeManager.primaryColor, lineWidth: 1)
                            .frame(width: 100, height: 100)

                        // Inner diamond
                        ZStack {
                            Rectangle()
                                .fill(themeManager.primaryColor)
                                .frame(width: 40, height: 40)
                                .rotationEffect(.degrees(45))

                            // Center dot
                            Circle()
                                .fill(Color.black)
                                .frame(width: 8, height: 8)
                        }

                        // Corner brackets
                        ForEach(0..<4, id: \.self) { corner in
                            TacticalBracket()
                                .rotationEffect(.degrees(Double(corner * 90)))
                        }
                    }
                    .opacity(logoOpacity)
                    .scaleEffect(logoOpacity)

                    // Title
                    VStack(spacing: 8) {
                        Text("iCODEC")
                            .font(.system(size: 32, design: .monospaced))
                            .fontWeight(.bold)
                            .foregroundColor(themeManager.primaryColor)
                            .opacity(logoOpacity)

                        Text("TACTICAL COMMUNICATION SYSTEM")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(themeManager.textColor.opacity(0.7))
                            .opacity(logoOpacity)
                    }
                }

                Spacer()

                // Loading section
                VStack(spacing: 20) {
                    // Progress indicator
                    HStack(spacing: 8) {
                        ForEach(0..<8, id: \.self) { index in
                            Rectangle()
                                .fill(index < Int(loadingProgress * 8) ? themeManager.primaryColor : themeManager.primaryColor.opacity(0.3))
                                .frame(width: 20, height: 4)
                                .animation(.easeInOut(duration: 0.3).delay(Double(index) * 0.1), value: loadingProgress)
                        }
                    }

                    // System messages
                    VStack(spacing: 4) {
                        ForEach(Array(systemMessages.enumerated()), id: \.offset) { index, message in
                            HStack {
                                Text("▶")
                                    .font(.system(size: 8, design: .monospaced))
                                    .foregroundColor(themeManager.accentColor)

                                Text(message)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(index == systemMessages.count - 1 ? themeManager.primaryColor : themeManager.textColor.opacity(0.6))

                                Spacer()
                            }
                            .opacity(index <= currentMessageIndex ? 1.0 : 0.0)
                            .animation(.easeIn(duration: 0.2), value: currentMessageIndex)
                        }
                    }
                    .frame(maxWidth: 280, alignment: .leading)
                }

                Spacer()
            }
            .padding(.horizontal, 40)
        }
        .onAppear {
            startBootSequence()
        }
    }

    private func startBootSequence() {
        // Logo animation
        withAnimation(.easeOut(duration: 1.0)) {
            logoOpacity = 1.0
        }

        // Grid animation
        withAnimation(.easeIn(duration: 0.8).delay(0.3)) {
            gridOpacity = 0.2
        }

        // Scanline animation
        withAnimation(.linear(duration: 3.0).repeatForever(autoreverses: false)) {
            scanlinePosition = UIScreen.main.bounds.height
        }

        // Progress animation
        withAnimation(.easeInOut(duration: 2.0).delay(0.5)) {
            loadingProgress = 1.0
        }

        // Message sequence
        for (index, message) in bootMessages.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8 + Double(index) * 0.3) {
                systemMessages.append(message)
                currentMessageIndex = index

                // Play tactical sound for each message
                if index % 2 == 0 {
                    TacticalSoundPlayer.playNavigation()
                }
            }
        }
    }
}

struct TacticalGrid: View {
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 30

            context.stroke(
                Path { path in
                    // Vertical lines
                    for x in stride(from: 0, through: size.width, by: spacing) {
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: size.height))
                    }

                    // Horizontal lines
                    for y in stride(from: 0, through: size.height, by: spacing) {
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: size.width, y: y))
                    }
                },
                with: .color(themeManager.primaryColor),
                lineWidth: 0.5
            )
        }
    }
}

struct TacticalBracket: View {
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        VStack {
            HStack {
                Rectangle()
                    .fill(themeManager.primaryColor)
                    .frame(width: 12, height: 2)
                Rectangle()
                    .fill(themeManager.primaryColor)
                    .frame(width: 2, height: 12)
            }
            .offset(x: 50, y: -50)
            Spacer()
        }
    }
}

struct StatCounter: View {
    let label: String
    let value: Int
    let color: Color
    let isInteractive: Bool
    @EnvironmentObject private var themeManager: ThemeManager

    init(label: String, value: Int, color: Color, isInteractive: Bool = false) {
        self.label = label
        self.value = value
        self.color = color
        self.isInteractive = isInteractive
    }

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
        .scaleEffect(isInteractive ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isInteractive)
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

                let dayFormatter = DateFormatter()
                dayFormatter.dateFormat = "MM/dd"
                return (label: dayFormatter.string(from: date), value: count)
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

                let monthFormatter = DateFormatter()
                monthFormatter.dateFormat = "MMM"
                return (label: monthFormatter.string(from: date), value: count)
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

                let monthFormatter = DateFormatter()
                monthFormatter.dateFormat = "MMM"
                return (label: monthFormatter.string(from: date), value: count)
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
