import Foundation
import SwiftData

@Model
final class MapLayer {
    var id: UUID
    var name: String
    /// 0 = bottom-most layer, up to 4 = top-most
    var sortOrder: Int
    var isVisible: Bool
    var isLocked: Bool
    /// Layer opacity from 0.0 (transparent) to 1.0 (opaque)
    var opacity: Double
    /// Raw value of LayerType enum. Defaults to 0 (tile) for backward compatibility.
    var layerTypeRaw: Int

    // MARK: - Grid Layer Properties (only meaningful when layerType == .grid)

    /// Grid line width in points.
    var gridLineWidth: Double
    /// Grid line color (RGBA).
    var gridColorRed: Double
    var gridColorGreen: Double
    var gridColorBlue: Double
    var gridColorAlpha: Double
    /// Whether coordinate labels are shown on the grid.
    var gridShowCoordinateLabels: Bool

    /// Type-safe access to the layer type.
    var layerType: LayerType {
        get { LayerType(rawValue: layerTypeRaw) ?? .tile }
        set { layerTypeRaw = newValue.rawValue }
    }

    var project: MapProject?

    @Relationship(deleteRule: .cascade, inverse: \PlacedTile.layer)
    var placedTiles: [PlacedTile]

    @Relationship(deleteRule: .cascade, inverse: \TextAnnotation.layer)
    var textAnnotations: [TextAnnotation]

    @Relationship(deleteRule: .cascade, inverse: \DrawingStroke.layer)
    var drawingStrokes: [DrawingStroke]

    init(name: String, sortOrder: Int, layerTypeRaw: Int = 0) {
        self.id = UUID()
        self.name = name
        self.sortOrder = sortOrder
        self.isVisible = true
        self.isLocked = false
        self.opacity = 1.0
        self.layerTypeRaw = layerTypeRaw
        self.placedTiles = []
        self.textAnnotations = []
        self.drawingStrokes = []
        // Grid defaults (only meaningful when layerType == .grid)
        self.gridLineWidth = 1.5
        self.gridColorRed = 1.0
        self.gridColorGreen = 1.0
        self.gridColorBlue = 1.0
        self.gridColorAlpha = 1.0
        self.gridShowCoordinateLabels = true
    }
}
