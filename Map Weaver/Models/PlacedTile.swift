import Foundation
import SwiftData

@Model
final class PlacedTile {
    var id: UUID
    /// Grid column index (can be negative for infinite canvas)
    var gridX: Int
    /// Grid row index (can be negative for infinite canvas)
    var gridY: Int

    var layer: MapLayer?
    var asset: TileAsset?

    init(gridX: Int, gridY: Int, asset: TileAsset) {
        self.id = UUID()
        self.gridX = gridX
        self.gridY = gridY
        self.asset = asset
    }
}
