import SwiftUI
import SwiftData

@Observable
final class MapEditorViewModel {
    // MARK: - Canvas Transform

    var panOffset: CGSize = .zero
    var zoomScale: CGFloat = 1.0

    static let minZoom: CGFloat = 0.1
    static let maxZoom: CGFloat = 5.0

    /// Canvas view size, updated by CanvasView's GeometryReader.
    var canvasSize: CGSize = .zero

    // MARK: - Asset / Layer State

    var traySelectedAsset: TileAsset?
    var activeLayer: MapLayer? {
        didSet {
            if activeLayer?.layerType == .background || activeLayer?.layerType == .grid {
                activeLayer = oldValue
            }
        }
    }

    // MARK: - Selection State

    /// The currently selected placed tile (for move operations).
    var selectedTile: PlacedTile?
    /// The currently selected text annotation (for move operations).
    var selectedTextAnnotation: TextAnnotation?
    /// The currently selected drawing stroke (for move operations).
    var selectedDrawingStroke: DrawingStroke?
    /// Whether the user is actively dragging the selected item.
    var isDraggingSelection = false
    /// Canvas-space offset applied during drag of text/drawing items.
    var dragCanvasOffset: CGSize = .zero
    /// Canvas-space point where the drag began.
    var dragStartCanvasPoint: CGPoint = .zero

    // MARK: - Context Menu State

    /// The tile being targeted by the long-press context menu.
    var contextMenuTile: PlacedTile?
    /// The text annotation being targeted by the long-press context menu.
    var contextMenuTextAnnotation: TextAnnotation?
    /// The drawing stroke being targeted by the long-press context menu.
    var contextMenuDrawingStroke: DrawingStroke?
    /// Whether the context menu is currently showing.
    var showContextMenu = false
    /// Screen position where the context menu should appear.
    var contextMenuPosition: CGPoint = .zero

    func dismissContextMenu() {
        contextMenuTile = nil
        contextMenuTextAnnotation = nil
        contextMenuDrawingStroke = nil
        showContextMenu = false
    }

    // MARK: - In-Memory Tile Lookup

    /// Key format: "layerPersistentID-gridX-gridY"
    var tileLookup: [String: PlacedTile] = [:]

    // MARK: - Undo/Redo

    let undoService = UndoService()

    // MARK: - Text Editing State

    /// The text annotation currently being edited (nil when not editing).
    var editingTextAnnotation: TextAnnotation?
    /// Whether the text editor overlay is showing.
    var isShowingTextEditor = false
    /// Screen position where the text editor should appear.
    var textEditorPosition: CGPoint = .zero
    /// Whether the text annotation is new (not yet inserted into model context).
    var isNewTextAnnotation = false
    /// Color for new text annotations (RGBA).
    var newTextColorRed: Double = 1.0
    var newTextColorGreen: Double = 1.0
    var newTextColorBlue: Double = 1.0
    var newTextColorAlpha: Double = 1.0
    /// Font size for new text annotations.
    var newTextFontSize: Double = 16.0

    /// Whether the active layer is a text layer.
    var isTextLayerActive: Bool {
        activeLayer?.layerType == .text
    }

    /// Whether the active layer is a drawing layer.
    var isDrawingLayerActive: Bool {
        activeLayer?.layerType == .drawing
    }

    /// Find a text annotation near a screen point on the active text layer.
    func textAnnotation(near screenPoint: CGPoint, padding: CGFloat = 16) -> TextAnnotation? {
        guard let layer = activeLayer, layer.layerType == .text else { return nil }
        for annotation in layer.textAnnotations {
            let screenX = CGFloat(annotation.canvasX) * zoomScale + panOffset.width
            let screenY = CGFloat(annotation.canvasY) * zoomScale + panOffset.height
            let fontSize = CGFloat(annotation.fontSize) * zoomScale
            // Approximate text bounding box
            let textWidth = max(fontSize * CGFloat(annotation.text.count) * 0.6, 40)
            let textHeight = max(fontSize * 1.3, 24)
            let hitRect = CGRect(
                x: screenX - padding,
                y: screenY - padding,
                width: textWidth + padding * 2,
                height: textHeight + padding * 2
            )
            if hitRect.contains(screenPoint) {
                return annotation
            }
        }
        return nil
    }

    /// Find a drawing stroke near a screen point on the active drawing layer.
    func drawingStroke(near screenPoint: CGPoint, padding: CGFloat = 16) -> DrawingStroke? {
        guard let layer = activeLayer, layer.layerType == .drawing else { return nil }
        for stroke in layer.drawingStrokes {
            guard !stroke.points.isEmpty else { continue }
            var minX = CGFloat.greatestFiniteMagnitude
            var minY = CGFloat.greatestFiniteMagnitude
            var maxX = -CGFloat.greatestFiniteMagnitude
            var maxY = -CGFloat.greatestFiniteMagnitude
            for point in stroke.points {
                let sx = CGFloat(point.x) * zoomScale + panOffset.width
                let sy = CGFloat(point.y) * zoomScale + panOffset.height
                minX = min(minX, sx); minY = min(minY, sy)
                maxX = max(maxX, sx); maxY = max(maxY, sy)
            }
            // Ensure minimum hit area for thin/small strokes
            let halfLineWidth = max(CGFloat(stroke.lineWidth) * zoomScale / 2, 10)
            let hitRect = CGRect(
                x: minX - padding - halfLineWidth,
                y: minY - padding - halfLineWidth,
                width: maxX - minX + (padding + halfLineWidth) * 2,
                height: maxY - minY + (padding + halfLineWidth) * 2
            )
            if hitRect.contains(screenPoint) {
                return stroke
            }
        }
        return nil
    }

    // MARK: - Stroke Editing State

    /// The drawing stroke currently being edited (color/width).
    var editingDrawingStroke: DrawingStroke?
    /// Whether the stroke editor overlay is showing.
    var isShowingStrokeEditor = false

    // MARK: - Drawing State

    /// Whether drawing mode is active (finger draws instead of panning).
    var isDrawingModeActive = false
    /// The stroke currently being drawn (not yet committed to model).
    var activeStrokePoints: [StrokePoint] = []
    /// Color for new strokes (RGBA).
    var newStrokeColorRed: Double = 1.0
    var newStrokeColorGreen: Double = 1.0
    var newStrokeColorBlue: Double = 1.0
    var newStrokeColorAlpha: Double = 1.0
    /// Line width for new strokes.
    var newStrokeLineWidth: Double = 3.0

    // MARK: - Background Image

    var backgroundImage: UIImage?

    func loadBackgroundImage() {
        guard let fileName = project.backgroundImageFileName else {
            backgroundImage = nil
            return
        }
        backgroundImage = ImageCache.shared.backgroundImage(for: project.id, fileName: fileName)
    }

    // MARK: - Project

    let project: MapProject

    init(project: MapProject) {
        self.project = project
        if let firstLayer = project.layers
            .filter({ $0.layerType != .background && $0.layerType != .grid })
            .sorted(by: { $0.sortOrder < $1.sortOrder }).first {
            self.activeLayer = firstLayer
        }
        buildTileLookup()
        loadBackgroundImage()
    }

    // MARK: - Tile Lookup

    func buildTileLookup() {
        tileLookup.removeAll()
        for layer in project.layers {
            for tile in layer.placedTiles {
                let w = tile.asset?.gridWidth ?? 1
                let h = tile.asset?.gridHeight ?? 1
                for dx in 0..<w {
                    for dy in 0..<h {
                        let key = tileKey(layerID: layer.id, x: tile.gridX + dx, y: tile.gridY + dy)
                        tileLookup[key] = tile
                    }
                }
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

    func gridToCanvas(position: GridPosition, cellSize: CGFloat, gridWidth: Int = 1, gridHeight: Int = 1) -> CGRect {
        let x = CGFloat(position.x) * cellSize
        let y = CGFloat(position.y) * cellSize
        return CGRect(x: x, y: y, width: cellSize * CGFloat(gridWidth), height: cellSize * CGFloat(gridHeight))
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

    // MARK: - Selection

    func clearSelection() {
        selectedTile = nil
        selectedTextAnnotation = nil
        selectedDrawingStroke = nil
        isDraggingSelection = false
        dragCanvasOffset = .zero
    }

    // MARK: - Zoom

    /// Zoom to a new scale, keeping the anchor point fixed on screen.
    func zoomToward(newScale: CGFloat, anchor: CGPoint) {
        let clamped = min(max(newScale, Self.minZoom), Self.maxZoom)
        let canvasX = (anchor.x - panOffset.width) / zoomScale
        let canvasY = (anchor.y - panOffset.height) / zoomScale
        panOffset = CGSize(
            width: anchor.x - canvasX * clamped,
            height: anchor.y - canvasY * clamped
        )
        zoomScale = clamped
    }

    /// Zoom toward the center of the canvas.
    func zoomTowardCenter(newScale: CGFloat) {
        let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
        zoomToward(newScale: newScale, anchor: center)
    }

}
