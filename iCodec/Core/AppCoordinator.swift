import SwiftUI
import Combine

@MainActor
class AppCoordinator: ObservableObject {
    @Published var currentModule: AppModule = .mission
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

enum AppModule: String, CaseIterable {
    case mission = "MISSION"
    case map = "MAP"
    case compass = "COMPASS"
    case audio = "AUDIO"
    case intel = "INTEL"
    case alerts = "ALERTS"
    case camera = "CAMERA"
    case settings = "SETTINGS"

    static var navigationModules: [AppModule] {
        [.mission, .map, .audio, .intel, .alerts, .camera, .compass]
    }

    var glyph: String {
        switch self {
        case .mission: return "OBJ"
        case .map: return "TAC"
        case .compass: return "NAV"
        case .audio: return "COM"
        case .intel: return "INT"
        case .alerts: return "ALR"
        case .camera: return "CAM"
        case .settings: return "SET"
        }
    }
}

enum NavigationDestination: Hashable {
    case missionDetail(UUID)
    case audioDetail(UUID)
    case settings
    case about
}
