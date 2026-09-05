import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ProjectListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MapProject.modifiedAt, order: .reverse) private var projects: [MapProject]
    @Query(sort: \ProjectFolder.createdAt) private var folders: [ProjectFolder]

    @State private var showingNewProjectSheet = false
    @State private var showingNewFolderAlert = false
    @State private var newProjectName = ""
    @State private var newProjectGridSize = 64
    @State private var newFolderName = ""
    @State private var showingImportPicker = false
    @State private var importError: String?
    @State private var showingRenameFolderAlert = false
    @State private var renameFolderName = ""
    @State private var folderToRename: ProjectFolder?

    /// Projects not assigned to any folder
    private var ungroupedProjects: [MapProject] {
        projects.filter { $0.folder == nil }
    }

    var body: some View {
        Group {
            if folders.isEmpty && projects.isEmpty {
                ContentUnavailableView {
                    Label("No Maps Yet", systemImage: "map")
                } description: {
                    Text("Tap the + button to create your first dungeon map.")
                }
            } else {
                List {
                    if !folders.isEmpty {
                        Section("Folders") {
                            ForEach(folders) { folder in
                                NavigationLink(value: folder) {
                                    FolderRowView(folder: folder)
                                }
                                .contextMenu {
                                    Button {
                                        folderToRename = folder
                                        renameFolderName = folder.name
                                        showingRenameFolderAlert = true
                                    } label: {
                                        Label("Rename", systemImage: "pencil")
                                    }
                                    Button(role: .destructive) {
                                        withAnimation {
                                            modelContext.delete(folder)
                                        }
                                    } label: {
                                        Label("Delete Folder", systemImage: "trash")
                                    }
                                }
                            }
                            .onDelete(perform: deleteFolders)
                        }
                    }

                    Section(folders.isEmpty ? "Maps" : "Ungrouped Maps") {
                        ForEach(ungroupedProjects) { project in
                            NavigationLink(value: project) {
                                ProjectRowView(project: project)
                            }
                            .contextMenu {
                                if !folders.isEmpty {
                                    Menu {
                                        ForEach(folders) { folder in
                                            Button(folder.name) {
                                                withAnimation {
                                                    project.folder = folder
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
                        .onDelete(perform: deleteUngroupedProjects)
                    }
                }
            }
        }
        .navigationTitle("Map Weaver")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    showingImportPicker = true
                } label: {
                    Label("Import", systemImage: "square.and.arrow.down")
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        newProjectName = ""
                        newProjectGridSize = 64
                        showingNewProjectSheet = true
                    } label: {
                        Label("New Map", systemImage: "map")
                    }
                    Button {
                        newFolderName = ""
                        showingNewFolderAlert = true
                    } label: {
                        Label("New Folder", systemImage: "folder.badge.plus")
                    }
                } label: {
                    Label("Add", systemImage: "plus")
                }
            }
        }
        .fileImporter(
            isPresented: $showingImportPicker,
            allowedContentTypes: [UTType(filenameExtension: "mapweaver") ?? .json],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result: result)
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
        .alert("New Folder", isPresented: $showingNewFolderAlert) {
            TextField("Folder Name", text: $newFolderName)
            Button("Create") {
                createFolder()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Enter a name for the new folder.")
        }
        .alert("Import Error", isPresented: Binding(
            get: { importError != nil },
            set: { if !$0 { importError = nil } }
        )) {
            Button("OK") { importError = nil }
        } message: {
            Text(importError ?? "")
        }
        .alert("Rename Folder", isPresented: $showingRenameFolderAlert) {
            TextField("Folder Name", text: $renameFolderName)
            Button("Rename") {
                let trimmed = renameFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
                if let folder = folderToRename, !trimmed.isEmpty {
                    folder.name = trimmed
                }
                folderToRename = nil
            }
            Button("Cancel", role: .cancel) {
                folderToRename = nil
            }
        } message: {
            Text("Enter a new name for the folder.")
        }
    }

    private func createProject() {
        let trimmedName = newProjectName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        withAnimation {
            let project = MapProject(name: trimmedName, gridCellSize: newProjectGridSize)
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
            modelContext.insert(project)
        }
    }

    private func createFolder() {
        let trimmedName = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        withAnimation {
            let folder = ProjectFolder(name: trimmedName)
            modelContext.insert(folder)
        }
    }

    private func handleImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            do {
                _ = try ImportService.importBundle(from: url, modelContext: modelContext)
                importError = nil
            } catch {
                importError = error.localizedDescription
            }
        case .failure(let error):
            importError = error.localizedDescription
        }
    }

    private func deleteUngroupedProjects(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(ungroupedProjects[index])
            }
        }
    }

    private func deleteFolders(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(folders[index])
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
