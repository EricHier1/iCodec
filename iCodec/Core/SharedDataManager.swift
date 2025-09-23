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
    @Published var audioViewModel = AudioViewModel()

    // App Coordinator for navigation
    var appCoordinator: AppCoordinator?

    // Mission Stats
    @Published var activeMissionCount: Int = 0
    @Published var todayCompletedCount: Int = 0
    @Published var totalCompletedCount: Int = 0

    private var cancellables = Set<AnyCancellable>()

    private init() {
        // Private initializer for singleton
        setupMissionStatsObservers()
        setupAudioViewModelObserver()
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

    private func setupAudioViewModelObserver() {
        // Subscribe to audio view model changes to propagate them to UI
        audioViewModel.objectWillChange
            .sink { [weak self] _ in
                print("📢 SharedDataManager: AudioViewModel changed, propagating to UI")
                DispatchQueue.main.async {
                    self?.objectWillChange.send()
                }
            }
            .store(in: &cancellables)
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