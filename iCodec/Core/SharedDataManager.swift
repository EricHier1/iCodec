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

    private init() {
        // Private initializer for singleton
    }
}