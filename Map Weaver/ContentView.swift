import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        NavigationStack {
            ProjectListView()
                .navigationDestination(for: MapProject.self) { project in
                    MapEditorView(project: project)
                }
                .navigationDestination(for: ProjectFolder.self) { folder in
                    FolderContentView(folder: folder)
                }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: MapProject.self, inMemory: true)
}
