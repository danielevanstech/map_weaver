import Foundation
import SwiftData

@Model
final class MapProject {
    var id: UUID
    var name: String
    var createdAt: Date
    var modifiedAt: Date

    /// Pixels per grid cell (e.g., 64, 128)
    var gridCellSize: Int
    var showGridLines: Bool
    var showCoordinateLabels: Bool

    @Relationship(deleteRule: .cascade, inverse: \MapLayer.project)
    var layers: [MapLayer]

    @Relationship(deleteRule: .cascade, inverse: \TileAsset.project)
    var assets: [TileAsset]

    init(name: String, gridCellSize: Int = 64) {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
        self.modifiedAt = Date()
        self.gridCellSize = gridCellSize
        self.showGridLines = true
        self.showCoordinateLabels = true
        self.layers = []
        self.assets = []
    }
}
