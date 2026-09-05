import SwiftUI
import SwiftData

@main
struct Map_WeaverApp: App {
    var sharedModelContainer: ModelContainer = {
        // Ensure the Application Support directory exists before SwiftData tries to write to it.
        // CoreData/SwiftData defaults to this path for the SQLite store, and on first launch
        // the directory may not yet exist, causing sandbox write errors.
        let fileManager = FileManager.default
        if let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            if !fileManager.fileExists(atPath: appSupportURL.path) {
                try? fileManager.createDirectory(at: appSupportURL, withIntermediateDirectories: true)
            }
        }

        let schema = Schema([
            MapProject.self,
            MapLayer.self,
            PlacedTile.self,
            TileAsset.self,
            ProjectFolder.self,
            TextAnnotation.self,
            DrawingStroke.self,
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // Schema migration failed — delete the old store and retry
            if let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                let storeURL = appSupportURL.appendingPathComponent("default.store")
                for suffix in ["", "-wal", "-shm"] {
                    let fileURL = storeURL.deletingPathExtension().appendingPathExtension("store\(suffix)")
                    try? FileManager.default.removeItem(at: fileURL)
                }
            }
            do {
                return try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                fatalError("Could not create ModelContainer: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
