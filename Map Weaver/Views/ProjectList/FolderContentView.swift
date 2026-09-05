import SwiftUI
import SwiftData

struct FolderContentView: View {
    @Bindable var folder: ProjectFolder
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ProjectFolder.createdAt) private var allFolders: [ProjectFolder]

    @State private var showingNewProjectSheet = false
    @State private var newProjectName = ""
    @State private var newProjectGridSize = 64

    private var sortedProjects: [MapProject] {
        folder.projects.sorted { $0.modifiedAt > $1.modifiedAt }
    }

    var body: some View {
        Group {
            if folder.projects.isEmpty {
                ContentUnavailableView {
                    Label("Empty Folder", systemImage: "folder")
                } description: {
                    Text("Tap + to create a new map in this folder.")
                }
            } else {
                List {
                    ForEach(sortedProjects) { project in
                        NavigationLink(value: project) {
                            ProjectRowView(project: project)
                        }
                        .contextMenu {
                            Button {
                                withAnimation {
                                    project.folder = nil
                                    project.modifiedAt = Date()
                                }
                            } label: {
                                Label("Move to Top Level", systemImage: "arrow.up.doc")
                            }
                            let otherFolders = allFolders.filter { $0.id != folder.id }
                            if !otherFolders.isEmpty {
                                Menu {
                                    ForEach(otherFolders) { target in
                                        Button(target.name) {
                                            withAnimation {
                                                project.folder = target
                                                project.modifiedAt = Date()
                                            }
                                        }
                                    }
                                } label: {
                                    Label("Move to Folder", systemImage: "folder")
                                }
                            }
                        }
                    }
                    .onDelete(perform: deleteProjects)
                }
            }
        }
        .navigationTitle(folder.name)
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
            Button("Create") { createProject() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Enter a name for your new dungeon map.")
        }
    }

    private func createProject() {
        let trimmed = newProjectName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        withAnimation {
            let project = MapProject(name: trimmed, gridCellSize: newProjectGridSize)
            let gridLayer = MapLayer(name: "Grid", sortOrder: -2, layerTypeRaw: LayerType.grid.rawValue)
            gridLayer.opacity = 0.3
            gridLayer.isLocked = true
            let bgLayer = MapLayer(name: "Background", sortOrder: -1, layerTypeRaw: LayerType.background.rawValue)
            bgLayer.opacity = 0.3
            bgLayer.isLocked = true
            let groundLayer = MapLayer(name: "Ground", sortOrder: 0)
            let drawingLayer = MapLayer(name: "Drawing", sortOrder: 1, layerTypeRaw: LayerType.drawing.rawValue)
            let textLayer = MapLayer(name: "Text", sortOrder: 2, layerTypeRaw: LayerType.text.rawValue)
            project.layers.append(contentsOf: [gridLayer, bgLayer, groundLayer, drawingLayer, textLayer])
            project.folder = folder
            modelContext.insert(project)
        }
    }

    private func deleteProjects(offsets: IndexSet) {
        let sorted = sortedProjects
        withAnimation {
            for index in offsets {
                modelContext.delete(sorted[index])
            }
        }
    }
}
