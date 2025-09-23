import SwiftUI
import Combine

@MainActor
class SharedDataManager: ObservableObject {
    static let shared = SharedDataManager()

    // Shared ViewModels
    let missionViewModel = MissionViewModel()
    let alertsViewModel = AlertsViewModel()
    let intelViewModel = IntelViewModel()
    let mapViewModel = MapViewModel()
    let audioViewModel = AudioViewModel()

    // Mission Stats
    @Published var activeMissionCount: Int = 0
    @Published var todayCompletedCount: Int = 0
    @Published var totalCompletedCount: Int = 0

    private var cancellables = Set<AnyCancellable>()

    private init() {
        // Private initializer for singleton
        setupMissionStatsObservers()
    }

    private func setupMissionStatsObservers() {
        // Subscribe to mission changes and update stats
        missionViewModel.objectWillChange
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.updateMissionStats()
                }
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