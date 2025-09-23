import CoreData
import CloudKit

struct PersistenceController {
    static let shared = PersistenceController()

    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext

        let sampleMission = Mission(context: viewContext)
        sampleMission.id = UUID()
        sampleMission.name = "Operation: Silent Eagle"
        sampleMission.status = "active"
        sampleMission.timestamp = Date()
        sampleMission.latitude = 37.7749
        sampleMission.longitude = -122.4194

        do {
            try viewContext.save()
        } catch {
            print("Error saving preview context: \(error)")
        }
        return result
    }()

    let container: NSPersistentCloudKitContainer

    init(inMemory: Bool = false) {
        container = NSPersistentCloudKitContainer(name: "iCodec")

        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        } else {
            guard let description = container.persistentStoreDescriptions.first else {
                print("Warning: Failed to retrieve a persistent store description.")
                return
            }

            description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        }

        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                print("Core Data error: \(error), \(error.userInfo)")
                // Handle the error gracefully - app can still function with limited capabilities
            }
        })

        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}

extension PersistenceController {
    func save() {
        let context = container.viewContext

        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Core Data save error: \(error)")
                // Attempt to rollback changes
                context.rollback()
            }
        }
    }
}