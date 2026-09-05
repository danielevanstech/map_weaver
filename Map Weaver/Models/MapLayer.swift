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

    var project: MapProject?

    @Relationship(deleteRule: .cascade, inverse: \PlacedTile.layer)
    var placedTiles: [PlacedTile]

    init(name: String, sortOrder: Int) {
        self.id = UUID()
        self.name = name
        self.sortOrder = sortOrder
        self.isVisible = true
        self.isLocked = false
        self.opacity = 1.0
        self.placedTiles = []
    }
}
