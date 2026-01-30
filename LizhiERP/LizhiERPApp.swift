import SwiftUI
import SwiftData
import FirebaseCore

@main
struct LizhiERPApp: App {
    let container: ModelContainer

    init() {
        FirebaseApp.configure()

        let schema = Schema([
            Transaction.self,
            AssetEntity.self,
            Subscription.self,
            PhysicalAsset.self,
            CategoryEntity.self,
            StockTransaction.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            container = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
             print("CRITICAL: Failed to create ModelContainer: \(error)")
             
             // Attempt to delete the store and recreate (Development Mode Nuke)
             let fileManager = FileManager.default
             if let supportDir = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                 let storeURL = supportDir.appendingPathComponent("default.store")
                 let shmURL = supportDir.appendingPathComponent("default.store-shm")
                 let walURL = supportDir.appendingPathComponent("default.store-wal")
                 
                 do {
                     if fileManager.fileExists(atPath: storeURL.path) {
                         try fileManager.removeItem(at: storeURL)
                     }
                     if fileManager.fileExists(atPath: shmURL.path) {
                         try fileManager.removeItem(at: shmURL)
                     }
                     if fileManager.fileExists(atPath: walURL.path) {
                         try fileManager.removeItem(at: walURL)
                     }
                     print("CRITICAL: Deleted corrupted store files.")
                 } catch {
                     print("CRITICAL: Failed to delete store files: \(error)")
                 }
             }
             
             // Retry creation
             do {
                 container = try ModelContainer(for: schema, configurations: [modelConfiguration])
                 print("CRITICAL: Re-created ModelContainer successfully after purge.")
             } catch {
                 fatalError("Failed to create ModelContainer even after purge: \(error)")
             }
        }
        
        // Seed if needed
        DataManager.shared.seedCategories(context: container.mainContext)
    }
    
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container) // Pass the manually created container
    }
}
