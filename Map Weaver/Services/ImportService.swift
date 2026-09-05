import Foundation
import SwiftData
import UIKit

/// Handles importing .mapweaver bundle files (self-contained JSON with embedded images).
enum ImportService {

    /// Imports a .mapweaver file from the given URL.
    /// Returns the created MapProject.
    @MainActor
    static func importBundle(from sourceURL: URL, modelContext: ModelContext) throws -> MapProject {
        // Access security-scoped resource if needed
        let accessing = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if accessing { sourceURL.stopAccessingSecurityScopedResource() }
        }

        let jsonData = try Data(contentsOf: sourceURL)
        let exportModel = try JSONDecoder().decode(MapExportModel.self, from: jsonData)

        // Create a new project with fresh UUIDs
        let project = MapProject(
            name: exportModel.project.name,
            gridCellSize: exportModel.project.gridCellSize
        )
        project.showGridLines = exportModel.project.showGridLines
        project.showCoordinateLabels = exportModel.project.showCoordinateLabels
        modelContext.insert(project)

        // Map old IDs to new entities
        var layerMap: [String: MapLayer] = [:]
        var assetMap: [String: TileAsset] = [:]

        // Create layers
        for layerData in exportModel.layers {
            let layer = MapLayer(name: layerData.name, sortOrder: layerData.sortOrder)
            layer.isVisible = layerData.isVisible
            layer.isLocked = layerData.isLocked
            layer.opacity = layerData.opacity
            project.layers.append(layer)
            modelContext.insert(layer)
            layerMap[layerData.id] = layer
        }

        // Create assets and restore images from base64
        for assetData in exportModel.assets {
            let newAssetID = UUID()
            var relativePath = ""

            // Decode base64 image and save to disk
            if let base64String = assetData.imageData,
               let imageData = Data(base64Encoded: base64String),
               let image = UIImage(data: imageData) {
                do {
                    relativePath = try ImageStore.shared.save(
                        image: image,
                        projectID: project.id,
                        assetID: newAssetID
                    )
                } catch {
                    print("Failed to save imported image: \(error)")
                }
            }

            let asset = TileAsset(
                name: assetData.name,
                imageFileName: relativePath,
                category: assetData.category,
                gridWidth: assetData.gridWidth,
                gridHeight: assetData.gridHeight,
                hasTransparency: assetData.hasTransparency
            )
            asset.id = newAssetID
            project.assets.append(asset)
            modelContext.insert(asset)
            assetMap[assetData.id] = asset
        }

        // Create placed tiles
        for tileData in exportModel.tiles {
            guard let layer = layerMap[tileData.layerId],
                  let asset = assetMap[tileData.assetId] else { continue }

            let tile = PlacedTile(gridX: tileData.gridX, gridY: tileData.gridY, asset: asset)
            tile.layer = layer
            layer.placedTiles.append(tile)
            modelContext.insert(tile)
        }

        try modelContext.save()

        return project
    }
}
