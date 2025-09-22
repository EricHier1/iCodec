import SwiftUI
import CoreData

struct ContentView: View {
    @StateObject private var coordinator = AppCoordinator()
    @StateObject private var themeManager = ThemeManager()

    var body: some View {
        TabView(selection: $coordinator.currentTab) {
            HUDView()
                .tabItem {
                    Image(systemName: AppTab.hud.icon)
                    Text(AppTab.hud.rawValue)
                }
                .tag(AppTab.hud)

            CameraView()
                .tabItem {
                    Image(systemName: AppTab.camera.icon)
                    Text(AppTab.camera.rawValue)
                }
                .tag(AppTab.camera)

            MapView()
                .tabItem {
                    Image(systemName: AppTab.map.icon)
                    Text(AppTab.map.rawValue)
                }
                .tag(AppTab.map)

            AudioView()
                .tabItem {
                    Image(systemName: AppTab.audio.icon)
                    Text(AppTab.audio.rawValue)
                }
                .tag(AppTab.audio)

            SettingsView()
                .tabItem {
                    Image(systemName: AppTab.settings.icon)
                    Text(AppTab.settings.rawValue)
                }
                .tag(AppTab.settings)
        }
        .environmentObject(coordinator)
        .environmentObject(themeManager)
        .accentColor(themeManager.accentColor)
        .preferredColorScheme(.dark)
    }
}