import SwiftUI
import SwiftData

enum EditorTool: String, CaseIterable, Identifiable {
    case pan = "Pan"
    case paint = "Paint"
    case erase = "Erase"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .pan: return "hand.draw"
        case .paint: return "paintbrush"
        case .erase: return "eraser"
        }
    }
}

@Observable
final class MapEditorViewModel {
    // MARK: - Canvas Transform

    var panOffset: CGSize = .zero
    var lastPanOffset: CGSize = .zero
    var zoomScale: CGFloat = 1.0
    var lastZoomScale: CGFloat = 1.0

    static let minZoom: CGFloat = 0.1
    static let maxZoom: CGFloat = 5.0

    // MARK: - Tool State

    var selectedTool: EditorTool = .paint
    var selectedAsset: TileAsset?
    var activeLayer: MapLayer?

    // MARK: - In-Memory Tile Lookup

    /// Key format: "layerPersistentID-gridX-gridY"
    var tileLookup: [String: PlacedTile] = [:]

    // MARK: - Project

    let project: MapProject

    init(project: MapProject) {
        self.project = project
        if let firstLayer = project.layers.sorted(by: { $0.sortOrder < $1.sortOrder }).first {
            self.activeLayer = firstLayer
        }
        buildTileLookup()
    }

    // MARK: - Tile Lookup

    func buildTileLookup() {
        tileLookup.removeAll()
        for layer in project.layers {
            for tile in layer.placedTiles {
                let key = tileKey(layerID: layer.id, x: tile.gridX, y: tile.gridY)
                tileLookup[key] = tile
            }
        }
    }

    func tileKey(layerID: UUID, x: Int, y: Int) -> String {
        "\(layerID)-\(x)-\(y)"
    }

    func tile(at position: GridPosition, on layer: MapLayer) -> PlacedTile? {
        tileLookup[tileKey(layerID: layer.id, x: position.x, y: position.y)]
    }

    // MARK: - Coordinate Conversion

    func screenToGrid(point: CGPoint, cellSize: CGFloat) -> GridPosition {
        let canvasX = (point.x - panOffset.width) / zoomScale
        let canvasY = (point.y - panOffset.height) / zoomScale
        return GridPosition(
            x: Int(floor(canvasX / cellSize)),
            y: Int(floor(canvasY / cellSize))
        )
    }

    func gridToCanvas(position: GridPosition, cellSize: CGFloat) -> CGRect {
        let x = CGFloat(position.x) * cellSize
        let y = CGFloat(position.y) * cellSize
        return CGRect(x: x, y: y, width: cellSize, height: cellSize)
    }

    // MARK: - Visible Grid Rect

    func visibleGridRange(canvasSize: CGSize, cellSize: CGFloat) -> (minX: Int, maxX: Int, minY: Int, maxY: Int) {
        let topLeft = CGPoint(x: 0, y: 0)
        let bottomRight = CGPoint(x: canvasSize.width, y: canvasSize.height)

        let tlGrid = screenToGrid(point: topLeft, cellSize: cellSize)
        let brGrid = screenToGrid(point: bottomRight, cellSize: cellSize)

        // Add 1-cell buffer for partially visible tiles
        return (
            minX: tlGrid.x - 1,
            maxX: brGrid.x + 1,
            minY: tlGrid.y - 1,
            maxY: brGrid.y + 1
        )
    }

    // MARK: - Zoom

    func clampZoom() {
        zoomScale = min(max(zoomScale, Self.minZoom), Self.maxZoom)
        lastZoomScale = zoomScale
    }
}
