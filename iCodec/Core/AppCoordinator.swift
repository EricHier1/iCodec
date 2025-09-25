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
        // Listen for notification-based navigation requests
        NotificationCenter.default.publisher(for: .navigationRequested)
            .sink { [weak self] notification in
                if let destination = notification.object as? NavigationDestination {
                    self?.navigate(to: destination)
                }
            }
            .store(in: &cancellables)

        // Listen for module changes to trigger sound effects
        $currentModule
            .removeDuplicates()
            .dropFirst()
            .sink { _ in
                TacticalSoundPlayer.playNavigation()
            }
            .store(in: &cancellables)
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
    case audio = "AUDIO"
    case intel = "INTEL"
    case alerts = "ALERTS"
    case camera = "CAMERA"
    case settings = "SETTINGS"

    static var defaultNavigationModules: [AppModule] {
        [.mission, .map, .audio, .intel, .alerts, .camera]
    }

    static var navigationModules: [AppModule] {
        if let customOrder = UserDefaults.standard.array(forKey: "customTabOrder") as? [String] {
            let customModules = customOrder.compactMap { AppModule(rawValue: $0) }
            // Ensure all modules are present, add any missing ones
            let allModules = Set(defaultNavigationModules)
            let customSet = Set(customModules)
            let missing = allModules.subtracting(customSet)
            return customModules + Array(missing)
        }
        return defaultNavigationModules
    }

    static func saveCustomTabOrder(_ modules: [AppModule]) {
        let moduleStrings = modules.map { $0.rawValue }
        UserDefaults.standard.set(moduleStrings, forKey: "customTabOrder")
    }

    var glyph: String {
        switch self {
        case .mission: return "OBJ"
        case .map: return "TAC"
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

extension Notification.Name {
    static let navigationRequested = Notification.Name("navigationRequested")
}
