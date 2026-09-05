import SwiftUI
import SwiftData

struct MapEditorView: View {
    let project: MapProject
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: MapEditorViewModel?
    @State private var showingAssetLibrary = false
    @State private var showingLayerPanel = false
    @State private var showingExportMenu = false

    var body: some View {
        Group {
            if let viewModel {
                ZStack(alignment: .bottom) {
                    Color.black.ignoresSafeArea()
                    CanvasView(viewModel: viewModel)

                    // Context-appropriate toolbar stacked at bottom
                    VStack(spacing: 0) {
                        switch viewModel.activeLayer?.layerType {
                        case .tile:
                            if !project.assets.isEmpty {
                                AssetTrayView(
                                    project: project,
                                    viewModel: viewModel,
                                    onOpenLibrary: { showingAssetLibrary = true }
                                )
                            }
                        case .drawing:
                            DrawingToolbar(viewModel: viewModel)
                        case .text:
                            TextToolbar(viewModel: viewModel)
                        case .background, .grid, .none:
                            EmptyView()
                        }
                    }
                }
                .toolbar {
                    ToolbarItemGroup(placement: .navigationBarTrailing) {
                        Button {
                            showingExportMenu = true
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .accessibilityLabel("Export")

                        Button {
                            showingLayerPanel.toggle()
                        } label: {
                            Image(systemName: "square.3.layers.3d")
                        }
                        .accessibilityLabel("Layers")

                        Button {
                            showingAssetLibrary.toggle()
                        } label: {
                            Image(systemName: "square.grid.2x2")
                        }
                        .accessibilityLabel("Tile Assets")
                    }
                }
                .sheet(isPresented: $showingAssetLibrary) {
                    AssetLibraryView(
                        project: project,
                        selectedAsset: Binding(
                            get: { viewModel.traySelectedAsset },
                            set: { viewModel.traySelectedAsset = $0 }
                        )
                    )
                    .presentationDetents([.medium, .large])
                }
                .sheet(isPresented: $showingExportMenu) {
                    ExportMenuView(project: project)
                }
                .sheet(isPresented: $showingLayerPanel) {
                    LayerPanelView(
                        project: project,
                        activeLayer: Binding(
                            get: { viewModel.activeLayer },
                            set: { viewModel.activeLayer = $0 }
                        ),
                        viewModel: viewModel
                    )
                    .presentationDetents([.medium, .large])
                }
            } else {
                ProgressView("Loading map...")
            }
        }
        .navigationTitle(project.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if viewModel == nil {
                ensureBackgroundLayer()
                ensureGridLayer()
                viewModel = MapEditorViewModel(project: project)
            }
        }
    }

    // MARK: - Background Layer Migration

    private func ensureBackgroundLayer() {
        guard project.backgroundLayer == nil else { return }
        let bgLayer = MapLayer(name: "Background", sortOrder: -1, layerTypeRaw: LayerType.background.rawValue)
        bgLayer.opacity = project.backgroundOpacity
        bgLayer.isLocked = true
        modelContext.insert(bgLayer)
        project.layers.append(bgLayer)
    }

    // MARK: - Grid Layer Migration

    private func ensureGridLayer() {
        guard project.gridLayer == nil else { return }
        let gridLayer = MapLayer(name: "Grid", sortOrder: -2, layerTypeRaw: LayerType.grid.rawValue)
        gridLayer.isVisible = project.showGridLines
        gridLayer.gridShowCoordinateLabels = project.showCoordinateLabels
        gridLayer.isLocked = true
        gridLayer.opacity = 0.3
        gridLayer.gridLineWidth = 1.5
        if project.gridLinesBlack {
            gridLayer.gridColorRed = 0.0
            gridLayer.gridColorGreen = 0.0
            gridLayer.gridColorBlue = 0.0
        }
        modelContext.insert(gridLayer)
        project.layers.append(gridLayer)
    }
}
