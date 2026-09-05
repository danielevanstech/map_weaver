import Foundation
import SwiftData

@Model
final class TileAsset {
    var id: UUID
    var name: String
    /// Relative path within Documents/TileImages/ (e.g., "<projectID>/<assetID>.png")
    var imageFileName: String
    /// How many grid cells wide this asset spans (usually 1)
    var gridWidth: Int
    /// How many grid cells tall this asset spans (usually 1)
    var gridHeight: Int
    /// True for PNGs with alpha channel
    var hasTransparency: Bool
    /// User-created category name (e.g., "Ground", "Walls", "Enemies")
    var category: String
    var createdAt: Date

    var project: MapProject?

    @Relationship(deleteRule: .nullify, inverse: \PlacedTile.asset)
    var placements: [PlacedTile]

    init(name: String, imageFileName: String, category: String,
         gridWidth: Int = 1, gridHeight: Int = 1, hasTransparency: Bool = false) {
        self.id = UUID()
        self.name = name
        self.imageFileName = imageFileName
        self.gridWidth = gridWidth
        self.gridHeight = gridHeight
        self.hasTransparency = hasTransparency
        self.category = category
        self.createdAt = Date()
        self.placements = []
    }
}
