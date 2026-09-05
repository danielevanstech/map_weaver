import SwiftUI
import SwiftData

/// Handles placing and erasing tiles on the map grid.
@Observable
final class TilePlacementService {
    private let modelContext: ModelContext
    private let viewModel: MapEditorViewModel

    init(modelContext: ModelContext, viewModel: MapEditorViewModel) {
        self.modelContext = modelContext
        self.viewModel = viewModel
    }

    // MARK: - Place Tile

    /// Places a tile at the given grid position on the active layer.
    /// For multi-cell assets, the position is the top-left origin.
    /// Returns the placed tile, or nil if placement was not possible.
    @discardableResult
    func placeTile(at position: GridPosition, asset: TileAsset, layer: MapLayer) -> PlacedTile? {
        guard !layer.isLocked else { return nil }

        let w = asset.gridWidth
        let h = asset.gridHeight

        // Remove any existing tiles that overlap with the new tile's footprint
        for dx in 0..<w {
            for dy in 0..<h {
                let key = viewModel.tileKey(layerID: layer.id, x: position.x + dx, y: position.y + dy)
                if let existing = viewModel.tileLookup[key] {
                    removeTileFromLookup(existing, layer: layer)
                    modelContext.delete(existing)
                }
            }
        }

        // Create new tile
        let tile = PlacedTile(gridX: position.x, gridY: position.y, asset: asset)
        tile.layer = layer
        layer.placedTiles.append(tile)
        modelContext.insert(tile)

        // Register all cells in the lookup
        for dx in 0..<w {
            for dy in 0..<h {
                let key = viewModel.tileKey(layerID: layer.id, x: position.x + dx, y: position.y + dy)
                viewModel.tileLookup[key] = tile
            }
        }

        viewModel.project.modifiedAt = Date()
        return tile
    }

    // MARK: - Erase Tile

    /// Erases the tile at the given grid position on the active layer.
    /// If the position is covered by a multi-cell tile, the entire tile is removed.
    /// Returns true if a tile was erased.
    @discardableResult
    func eraseTile(at position: GridPosition, layer: MapLayer) -> Bool {
        guard !layer.isLocked else { return false }

        let key = viewModel.tileKey(layerID: layer.id, x: position.x, y: position.y)
        guard let existing = viewModel.tileLookup[key] else { return false }

        removeTileFromLookup(existing, layer: layer)
        modelContext.delete(existing)

        viewModel.project.modifiedAt = Date()
        return true
    }

    // MARK: - Move Tile

    /// Moves a placed tile from its current position to a new grid position.
    /// Returns true if the move succeeded.
    @discardableResult
    func moveTile(_ tile: PlacedTile, to newPosition: GridPosition, layer: MapLayer) -> Bool {
        guard !layer.isLocked else { return false }
        guard tile.gridX != newPosition.x || tile.gridY != newPosition.y else { return false }

        let w = tile.asset?.gridWidth ?? 1
        let h = tile.asset?.gridHeight ?? 1

        // Remove old lookup keys
        for dx in 0..<w {
            for dy in 0..<h {
                let key = viewModel.tileKey(layerID: layer.id, x: tile.gridX + dx, y: tile.gridY + dy)
                viewModel.tileLookup.removeValue(forKey: key)
            }
        }

        // Remove any existing tiles at the destination footprint
        for dx in 0..<w {
            for dy in 0..<h {
                let key = viewModel.tileKey(layerID: layer.id, x: newPosition.x + dx, y: newPosition.y + dy)
                if let existing = viewModel.tileLookup[key], existing.id != tile.id {
                    removeTileFromLookup(existing, layer: layer)
                    modelContext.delete(existing)
                }
            }
        }

        // Update position
        tile.gridX = newPosition.x
        tile.gridY = newPosition.y

        // Register new lookup keys
        for dx in 0..<w {
            for dy in 0..<h {
                let key = viewModel.tileKey(layerID: layer.id, x: newPosition.x + dx, y: newPosition.y + dy)
                viewModel.tileLookup[key] = tile
            }
        }

        viewModel.project.modifiedAt = Date()
        return true
    }

    // MARK: - Duplicate Tile

    /// Duplicates a placed tile, placing the copy offset to the right by the tile's width.
    @discardableResult
    func duplicateTile(_ tile: PlacedTile, on layer: MapLayer) -> PlacedTile? {
        guard let asset = tile.asset, !layer.isLocked else { return nil }
        let newPosition = GridPosition(x: tile.gridX + asset.gridWidth, y: tile.gridY)
        return placeTile(at: newPosition, asset: asset, layer: layer)
    }

    // MARK: - Batch Paint

    /// Places tiles along a path of grid positions. Returns count of tiles placed.
    @discardableResult
    func paintTiles(at positions: [GridPosition], asset: TileAsset, layer: MapLayer) -> Int {
        var count = 0
        for position in positions {
            if placeTile(at: position, asset: asset, layer: layer) != nil {
                count += 1
            }
        }
        return count
    }

    // MARK: - Private

    /// Removes all lookup keys for a placed tile (handles multi-cell tiles).
    private func removeTileFromLookup(_ tile: PlacedTile, layer: MapLayer) {
        let w = tile.asset?.gridWidth ?? 1
        let h = tile.asset?.gridHeight ?? 1
        for dx in 0..<w {
            for dy in 0..<h {
                let key = viewModel.tileKey(layerID: layer.id, x: tile.gridX + dx, y: tile.gridY + dy)
                viewModel.tileLookup.removeValue(forKey: key)
            }
        }
    }
}
