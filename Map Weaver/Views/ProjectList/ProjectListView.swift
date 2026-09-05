import SwiftUI
import SwiftData

struct ProjectListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MapProject.modifiedAt, order: .reverse) private var projects: [MapProject]

    @State private var showingNewProjectSheet = false
    @State private var newProjectName = ""
    @State private var newProjectGridSize = 64

    var body: some View {
        Group {
            if projects.isEmpty {
                ContentUnavailableView {
                    Label("No Maps Yet", systemImage: "map")
                } description: {
                    Text("Tap the + button to create your first dungeon map.")
                }
            } else {
                List {
                    ForEach(projects) { project in
                        NavigationLink(value: project) {
                            ProjectRowView(project: project)
                        }
                    }
                    .onDelete(perform: deleteProjects)
                }
            }
        }
        .navigationTitle("Map Weaver")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    newProjectName = ""
                    newProjectGridSize = 64
                    showingNewProjectSheet = true
                } label: {
                    Label("New Map", systemImage: "plus")
                }
            }
        }
        .alert("New Map", isPresented: $showingNewProjectSheet) {
            TextField("Map Name", text: $newProjectName)
            Button("Create") {
                createProject()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Enter a name for your new dungeon map.")
        }
    }

    private func createProject() {
        let trimmedName = newProjectName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        withAnimation {
            let project = MapProject(name: trimmedName, gridCellSize: newProjectGridSize)
            // Create a default "Ground" layer
            let groundLayer = MapLayer(name: "Ground", sortOrder: 0)
            project.layers.append(groundLayer)
            modelContext.insert(project)
        }
    }

    private func deleteProjects(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(projects[index])
            }
        }
    }
}

#Preview {
    NavigationStack {
        ProjectListView()
    }
    .modelContainer(for: MapProject.self, inMemory: true)
}
