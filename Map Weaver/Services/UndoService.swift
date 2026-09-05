import SwiftUI
import SwiftData

/// Represents a reversible editing action on the map.
protocol MapAction {
    func execute(context: ModelContext, viewModel: MapEditorViewModel)
    func undo(context: ModelContext, viewModel: MapEditorViewModel)
}

/// Places a single tile, optionally replacing existing ones under its footprint.
struct PlaceTileAction: MapAction {
    let gridX: Int
    let gridY: Int
    let gridWidth: Int
    let gridHeight: Int
    let layerID: UUID
    let assetID: UUID
    /// Tiles that were overwritten: (originX, originY, assetID, assetGridWidth, assetGridHeight)
    let previousTiles: [(Int, Int, UUID, Int, Int)]

    func execute(context: ModelContext, viewModel: MapEditorViewModel) {
        guard let layer = findLayer(id: layerID, in: viewModel),
              let asset = findAsset(id: assetID, in: viewModel) else { return }

        // Remove existing tiles under the footprint
        for (px, py, _, pw, ph) in previousTiles {
            let key = viewModel.tileKey(layerID: layerID, x: px, y: py)
            if let existing = viewModel.tileLookup[key] {
                removeLookupKeys(for: existing, layerID: layerID, gridWidth: pw, gridHeight: ph, viewModel: viewModel)
                context.delete(existing)
            }
        }

        // Place new tile
        let tile = PlacedTile(gridX: gridX, gridY: gridY, asset: asset)
        tile.layer = layer
        layer.placedTiles.append(tile)
        context.insert(tile)
        addLookupKeys(for: tile, layerID: layerID, gridWidth: gridWidth, gridHeight: gridHeight, viewModel: viewModel)
    }

    func undo(context: ModelContext, viewModel: MapEditorViewModel) {
        // Remove the tile we placed
        let key = viewModel.tileKey(layerID: layerID, x: gridX, y: gridY)
        if let placed = viewModel.tileLookup[key] {
            removeLookupKeys(for: placed, layerID: layerID, gridWidth: gridWidth, gridHeight: gridHeight, viewModel: viewModel)
            context.delete(placed)
        }

        // Restore previous tiles
        guard let layer = findLayer(id: layerID, in: viewModel) else { return }
        for (px, py, prevAssetID, pw, ph) in previousTiles {
            if let prevAsset = findAsset(id: prevAssetID, in: viewModel) {
                let restored = PlacedTile(gridX: px, gridY: py, asset: prevAsset)
                restored.layer = layer
                layer.placedTiles.append(restored)
                context.insert(restored)
                addLookupKeys(for: restored, layerID: layerID, gridWidth: pw, gridHeight: ph, viewModel: viewModel)
            }
        }
    }
}

/// Erases a single tile (which may span multiple cells).
struct EraseTileAction: MapAction {
    let gridX: Int
    let gridY: Int
    let gridWidth: Int
    let gridHeight: Int
    let layerID: UUID
    let erasedAssetID: UUID

    func execute(context: ModelContext, viewModel: MapEditorViewModel) {
        let key = viewModel.tileKey(layerID: layerID, x: gridX, y: gridY)
        if let existing = viewModel.tileLookup[key] {
            removeLookupKeys(for: existing, layerID: layerID, gridWidth: gridWidth, gridHeight: gridHeight, viewModel: viewModel)
            context.delete(existing)
        }
    }

    func undo(context: ModelContext, viewModel: MapEditorViewModel) {
        guard let layer = findLayer(id: layerID, in: viewModel),
              let asset = findAsset(id: erasedAssetID, in: viewModel) else { return }

        let tile = PlacedTile(gridX: gridX, gridY: gridY, asset: asset)
        tile.layer = layer
        layer.placedTiles.append(tile)
        context.insert(tile)
        addLookupKeys(for: tile, layerID: layerID, gridWidth: gridWidth, gridHeight: gridHeight, viewModel: viewModel)
    }
}

/// Groups multiple actions from a single drag gesture.
struct BatchAction: MapAction {
    let actions: [any MapAction]

    func execute(context: ModelContext, viewModel: MapEditorViewModel) {
        for action in actions {
            action.execute(context: context, viewModel: viewModel)
        }
    }

    func undo(context: ModelContext, viewModel: MapEditorViewModel) {
        for action in actions.reversed() {
            action.undo(context: context, viewModel: viewModel)
        }
    }
}

// MARK: - Helpers

private func findLayer(id: UUID, in viewModel: MapEditorViewModel) -> MapLayer? {
    viewModel.project.layers.first { $0.id == id }
}

private func findAsset(id: UUID, in viewModel: MapEditorViewModel) -> TileAsset? {
    viewModel.project.assets.first { $0.id == id }
}

private func addLookupKeys(for tile: PlacedTile, layerID: UUID, gridWidth: Int, gridHeight: Int, viewModel: MapEditorViewModel) {
    for dx in 0..<gridWidth {
        for dy in 0..<gridHeight {
            let key = viewModel.tileKey(layerID: layerID, x: tile.gridX + dx, y: tile.gridY + dy)
            viewModel.tileLookup[key] = tile
        }
    }
}

private func removeLookupKeys(for tile: PlacedTile, layerID: UUID, gridWidth: Int, gridHeight: Int, viewModel: MapEditorViewModel) {
    for dx in 0..<gridWidth {
        for dy in 0..<gridHeight {
            let key = viewModel.tileKey(layerID: layerID, x: tile.gridX + dx, y: tile.gridY + dy)
            viewModel.tileLookup.removeValue(forKey: key)
        }
    }
}

// MARK: - UndoService

@Observable
final class UndoService {
    private var undoStack: [any MapAction] = []
    private var redoStack: [any MapAction] = []

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    /// Perform an action and push it onto the undo stack.
    func perform(_ action: any MapAction, context: ModelContext, viewModel: MapEditorViewModel) {
        action.execute(context: context, viewModel: viewModel)
        undoStack.append(action)
        redoStack.removeAll()
    }

    func undo(context: ModelContext, viewModel: MapEditorViewModel) {
        guard let action = undoStack.popLast() else { return }
        action.undo(context: context, viewModel: viewModel)
        redoStack.append(action)
    }

    func redo(context: ModelContext, viewModel: MapEditorViewModel) {
        guard let action = redoStack.popLast() else { return }
        action.execute(context: context, viewModel: viewModel)
        undoStack.append(action)
    }

    func clear() {
        undoStack.removeAll()
        redoStack.removeAll()
    }
}
