import SwiftUI
import CoreData

@main
struct iCodecApp: App {
    let persistenceController = PersistenceController.shared

    init() {
        // Initialize CodecAlertManager early to set up notification delegate
        _ = CodecAlertManager.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .preferredColorScheme(.dark)
        }
    }
}