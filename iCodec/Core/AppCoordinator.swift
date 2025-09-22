import SwiftUI
import Combine

@MainActor
class AppCoordinator: ObservableObject {
    @Published var currentTab: AppTab = .hud
    @Published var navigationStack: [NavigationDestination] = []

    private var cancellables = Set<AnyCancellable>()

    init() {
        setupBindings()
    }

    private func setupBindings() {
    }

    func navigate(to destination: NavigationDestination) {
        navigationStack.append(destination)
    }

    func popToRoot() {
        navigationStack.removeAll()
    }

    func pop() {
        if !navigationStack.isEmpty {
            navigationStack.removeLast()
        }
    }
}

enum AppTab: String, CaseIterable {
    case hud = "HUD"
    case camera = "Camera"
    case map = "Map"
    case audio = "Audio"
    case settings = "Settings"

    var icon: String {
        switch self {
        case .hud: return "display"
        case .camera: return "camera.viewfinder"
        case .map: return "map"
        case .audio: return "waveform"
        case .settings: return "gear"
        }
    }
}

enum NavigationDestination: Hashable {
    case missionDetail(UUID)
    case audioDetail(UUID)
    case settings
    case about
}