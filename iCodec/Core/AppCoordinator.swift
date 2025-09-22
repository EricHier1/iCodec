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
    case intel = "INTEL"
    case alerts = "ALERTS"
    case audio = "AUDIO"

    var glyph: String {
        switch self {
        case .mission: return "OBJ"
        case .map: return "TAC"
        case .intel: return "INT"
        case .alerts: return "ALR"
        case .audio: return "COM"
        }
    }
}

enum NavigationDestination: Hashable {
    case missionDetail(UUID)
    case audioDetail(UUID)
    case settings
    case about
}