import SwiftUI
import SwiftData
import PhotosUI

struct LayerPanelView: View {
    let project: MapProject
    @Binding var activeLayer: MapLayer?
    var viewModel: MapEditorViewModel?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var showingAddLayer = false
    @State private var newLayerName = ""
    @State private var newLayerType: LayerType = .tile
    @State private var selectedBackgroundItem: PhotosPickerItem?

    private var sortedLayers: [MapLayer] {
        project.layers
            .filter { $0.layerType != .background && $0.layerType != .grid }
            .sorted { $0.sortOrder > $1.sortOrder }
    }

    private static let maxLayers = 7
    private static let displayedMaxLayers = 5

    private var tileLayerCount: Int {
        project.layers.filter { $0.layerType == .tile }.count
    }

    private var nonSpecialLayerCount: Int {
        project.layers.filter { $0.layerType != .background && $0.layerType != .grid }.count
    }

    var body: some View {
        NavigationStack {
            List {
                // Regular layers (movable, deletable)
                Section {
                    ForEach(sortedLayers) { layer in
                        LayerRowView(
                            layer: layer,
                            isActive: activeLayer?.id == layer.id,
                            onSelect: { activeLayer = layer }
                        )
                    }
                    .onMove(perform: moveLayer)
                    .onDelete(perform: deleteLayer)
                } footer: {
                    Text("\(tileLayerCount)/\(Self.displayedMaxLayers) tile layers")
                }

                // Grid layer (pinned, not movable/deletable)
                if let gridLayer = project.gridLayer {
                    Section("Grid") {
                        gridLayerRow(gridLayer)
                    }
                }

                // Background layer (pinned at bottom, not movable/deletable)
                if let bgLayer = project.backgroundLayer {
                    Section("Background") {
                        backgroundLayerRow(bgLayer)
                    }
                }
            }
            .navigationTitle("Layers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Menu {
                        Button {
                            newLayerName = ""
                            newLayerType = .tile
                            showingAddLayer = true
                        } label: {
                            Label("Tile Layer", systemImage: LayerType.tile.iconName)
                        }
                        Button {
                            newLayerName = ""
                            newLayerType = .drawing
                            showingAddLayer = true
                        } label: {
                            Label("Drawing Layer", systemImage: LayerType.drawing.iconName)
                        }
                        Button {
                            newLayerName = ""
                            newLayerType = .text
                            showingAddLayer = true
                        } label: {
                            Label("Text Layer", systemImage: LayerType.text.iconName)
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .disabled(nonSpecialLayerCount >= Self.maxLayers)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("New \(newLayerType.displayName) Layer", isPresented: $showingAddLayer) {
                TextField("Layer Name", text: $newLayerName)
                Button("Add") { addLayer() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Enter a name for the new \(newLayerType.displayName.lowercased()) layer.")
            }
            .onChange(of: selectedBackgroundItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    await loadBackgroundImage(from: newItem)
                    selectedBackgroundItem = nil
                }
            }
        }
    }

    // MARK: - Grid Layer Row

    @ViewBuilder
    private func gridLayerRow(_ gridLayer: MapLayer) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header row: icon, name, visibility
            HStack(spacing: 10) {
                Image(systemName: "grid")
                    .font(.system(size: 18))
                    .foregroundStyle(.secondary)
                    .frame(width: 24)

                Text("Grid")
                    .font(.body)

                Text("· Line overlay")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 4)

                Button {
                    gridLayer.isVisible.toggle()
                } label: {
                    Image(systemName: gridLayer.isVisible ? "eye.fill" : "eye.slash")
                        .font(.system(size: 18))
                        .foregroundStyle(gridLayer.isVisible ? .primary : .secondary)
                        .frame(minWidth: 36, minHeight: 36)
                }
                .buttonStyle(.borderless)
            }

            // Grid-specific controls (only shown when visible)
            if gridLayer.isVisible {
                // Opacity slider
                HStack(spacing: 8) {
                    Text("Opacity")
                        .font(.subheadline)
                    Text("\(Int(gridLayer.opacity * 100))%")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 36)
                    Slider(value: Binding(
                        get: { gridLayer.opacity },
                        set: { gridLayer.opacity = $0 }
                    ), in: 0.0...1.0)
                }
                ColorPicker("Line Color", selection: Binding(
                    get: {
                        Color(
                            red: gridLayer.gridColorRed,
                            green: gridLayer.gridColorGreen,
                            blue: gridLayer.gridColorBlue,
                            opacity: gridLayer.gridColorAlpha
                        )
                    },
                    set: { newColor in
                        let uiColor = UIColor(newColor)
                        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
                        gridLayer.gridColorRed = Double(r)
                        gridLayer.gridColorGreen = Double(g)
                        gridLayer.gridColorBlue = Double(b)
                        gridLayer.gridColorAlpha = Double(a)
                    }
                ))
                .font(.subheadline)

                HStack {
                    Text("Thickness")
                        .font(.subheadline)
                    Slider(value: Binding(
                        get: { gridLayer.gridLineWidth },
                        set: { gridLayer.gridLineWidth = $0 }
                    ), in: 0.5...5.0, step: 0.5)
                    Text(String(format: "%.1f", gridLayer.gridLineWidth))
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 28)
                }

                Toggle("Coordinate Labels", isOn: Binding(
                    get: { gridLayer.gridShowCoordinateLabels },
                    set: { gridLayer.gridShowCoordinateLabels = $0 }
                ))
                .font(.subheadline)
            }
        }
        .padding(.vertical, 6)
    }

    // MARK: - Background Layer Row

    @ViewBuilder
    private func backgroundLayerRow(_ bgLayer: MapLayer) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "photo")
                    .font(.system(size: 18))
                    .foregroundStyle(.secondary)
                    .frame(width: 24)

                Text("Background")
                    .font(.body)

                Text("· \(project.backgroundImageFileName != nil ? "Image set" : "No image")")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 4)

                Button {
                    bgLayer.isVisible.toggle()
                } label: {
                    Image(systemName: bgLayer.isVisible ? "eye.fill" : "eye.slash")
                        .font(.system(size: 18))
                        .foregroundStyle(bgLayer.isVisible ? .primary : .secondary)
                        .frame(minWidth: 36, minHeight: 36)
                }
                .buttonStyle(.borderless)
            }

            // Opacity slider
            if bgLayer.isVisible {
                HStack(spacing: 8) {
                    Text("Opacity")
                        .font(.subheadline)
                    Text("\(Int(bgLayer.opacity * 100))%")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 36)
                    Slider(value: Binding(
                        get: { bgLayer.opacity },
                        set: { bgLayer.opacity = $0 }
                    ), in: 0.05...1.0)
                }
            }

            // Background-specific controls
            if project.backgroundImageFileName != nil {
                Picker("Display Mode", selection: Binding(
                    get: { project.backgroundDisplayModeRaw },
                    set: { project.backgroundDisplayModeRaw = $0 }
                )) {
                    ForEach(BackgroundDisplayMode.allCases, id: \.rawValue) { mode in
                        Text(mode.displayName).tag(mode.rawValue)
                    }
                }
                .pickerStyle(.menu)
                .font(.subheadline)

                HStack {
                    PhotosPicker(
                        selection: $selectedBackgroundItem,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        Label("Change Image", systemImage: "photo.badge.arrow.down")
                            .font(.subheadline)
                    }

                    Spacer()

                    Button(role: .destructive) {
                        removeBackgroundImage()
                    } label: {
                        Label("Remove", systemImage: "trash")
                            .font(.subheadline)
                    }
                }
            } else {
                PhotosPicker(
                    selection: $selectedBackgroundItem,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    Label("Set Background Image", systemImage: "photo.badge.plus")
                        .font(.subheadline)
                }
            }
        }
        .padding(.vertical, 6)
    }

    // MARK: - Background Image Management

    @MainActor
    private func loadBackgroundImage(from item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }

        do {
            let fileName = try ImageStore.shared.saveBackgroundImage(image, projectID: project.id)
            project.backgroundImageFileName = fileName
            project.backgroundDisplayModeRaw = BackgroundDisplayMode.stretchToFit.rawValue
            ImageCache.shared.invalidateBackgroundImage(for: project.id)
            viewModel?.loadBackgroundImage()
        } catch {
            print("Failed to save background image: \(error)")
        }
    }

    private func removeBackgroundImage() {
        if let fileName = project.backgroundImageFileName {
            ImageStore.shared.deleteBackgroundImage(fileName: fileName)
            ImageCache.shared.invalidateBackgroundImage(for: project.id)
        }
        project.backgroundImageFileName = nil
        viewModel?.backgroundImage = nil
    }

    // MARK: - Layer Operations

    private func addLayer() {
        let trimmed = newLayerName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard nonSpecialLayerCount < Self.maxLayers else { return }

        let nextOrder = (project.layers.map(\.sortOrder).max() ?? -1) + 1
        let layer = MapLayer(name: trimmed, sortOrder: nextOrder, layerTypeRaw: newLayerType.rawValue)
        modelContext.insert(layer)
        project.layers.append(layer)
        activeLayer = layer
        project.modifiedAt = Date()
    }

    private func moveLayer(from source: IndexSet, to destination: Int) {
        var layers = sortedLayers
        layers.move(fromOffsets: source, toOffset: destination)
        // Reassign sort orders (reversed, since sortedLayers is top-first)
        for (index, layer) in layers.enumerated() {
            layer.sortOrder = layers.count - 1 - index
        }
        project.modifiedAt = Date()
    }

    private func deleteLayer(offsets: IndexSet) {
        let layers = sortedLayers
        for index in offsets {
            let layer = layers[index]
            if activeLayer?.id == layer.id {
                activeLayer = project.layers.first { $0.id != layer.id && $0.layerType != .background && $0.layerType != .grid }
            }
            modelContext.delete(layer)
        }
        project.modifiedAt = Date()
    }
}
