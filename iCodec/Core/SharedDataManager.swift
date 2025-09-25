import SwiftUI
import Combine

@MainActor
class SharedDataManager: ObservableObject {
    static let shared = SharedDataManager()

    // Shared ViewModels - using lazy initialization to avoid circular references
    lazy var missionViewModel = MissionViewModel()
    lazy var alertsViewModel = AlertsViewModel()
    lazy var intelViewModel = IntelViewModel()
    lazy var mapViewModel = MapViewModel()
    lazy var audioViewModel = AudioViewModel()

    // App Coordinator for navigation
    var appCoordinator: AppCoordinator?

    // Mission Stats
    @Published var activeMissionCount: Int = 0
    @Published var todayCompletedCount: Int = 0
    @Published var totalCompletedCount: Int = 0

    private var cancellables = Set<AnyCancellable>()

    private init() {
        // Private initializer for singleton
        // Delay setup to avoid circular references during initialization
        Task { @MainActor in
            setupMissionStatsObservers()
        }
    }

    private func setupMissionStatsObservers() {
        // Subscribe to mission changes and update stats
        missionViewModel.objectWillChange
            .sink { [weak self] _ in
                self?.updateMissionStats()
            }
            .store(in: &cancellables)

        // Initial stats calculation
        updateMissionStats()
    }

    func updateMissionStats() {
        // Active missions count (all non-completed missions including current active one)
        activeMissionCount = missionViewModel.missions.count

        // Today's completed missions
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        todayCompletedCount = missionViewModel.completedMissions.filter { mission in
            guard let timestamp = mission.timestamp else { return false }
            return calendar.isDate(timestamp, inSameDayAs: today) && mission.status == "completed"
        }.count

        // Total completed missions
        totalCompletedCount = missionViewModel.completedMissions.count
    }
}