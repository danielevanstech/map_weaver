import Foundation
import SwiftData
import UIKit
import os

private let logger = Logger(subsystem: "com.mapweaver", category: "ImportService")

/// Handles importing .mapweaver bundle files (self-contained JSON with embedded images).
enum ImportService {

    /// Imports a .mapweaver file from the given URL.
    /// Returns the created MapProject. Throws on critical failures;
    /// individual image decode failures are logged but do not abort the import.
    @MainActor
    static func importBundle(from sourceURL: URL, modelContext: ModelContext) throws -> MapProject {
        var imageRestoreFailures: [String] = []
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
        if let displayMode = exportModel.project.backgroundDisplayModeRaw {
            project.backgroundDisplayModeRaw = displayMode
        }
        if let opacity = exportModel.project.backgroundOpacity {
            project.backgroundOpacity = opacity
        }
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
            layer.layerTypeRaw = layerData.layerTypeRaw ?? 0
            // Restore grid-specific properties
            if layer.layerType == .grid {
                layer.gridLineWidth = layerData.gridLineWidth ?? 1.5
                layer.gridColorRed = layerData.gridColorRed ?? 1.0
                layer.gridColorGreen = layerData.gridColorGreen ?? 1.0
                layer.gridColorBlue = layerData.gridColorBlue ?? 1.0
                layer.gridColorAlpha = layerData.gridColorAlpha ?? 1.0
                layer.gridShowCoordinateLabels = layerData.gridShowCoordinateLabels ?? true
            }
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
                    imageRestoreFailures.append("\(assetData.name): \(error.localizedDescription)")
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

        // Restore text annotations
        if let annotationsData = exportModel.textAnnotations {
            for annData in annotationsData {
                guard let layer = layerMap[annData.layerId] else { continue }
                let annotation = TextAnnotation(
                    canvasX: annData.canvasX,
                    canvasY: annData.canvasY,
                    text: annData.text,
                    fontSize: annData.fontSize
                )
                annotation.colorRed = annData.colorRed
                annotation.colorGreen = annData.colorGreen
                annotation.colorBlue = annData.colorBlue
                annotation.colorAlpha = annData.colorAlpha
                annotation.layer = layer
                layer.textAnnotations.append(annotation)
                modelContext.insert(annotation)
            }
        }

        // Restore drawing strokes
        if let strokesData = exportModel.drawingStrokes {
            for strokeData in strokesData {
                guard let layer = layerMap[strokeData.layerId],
                      let pointsData = Data(base64Encoded: strokeData.pointsData) else { continue }
                let stroke = DrawingStroke(points: [], lineWidth: strokeData.lineWidth)
                stroke.pointsData = pointsData
                stroke.colorRed = strokeData.colorRed
                stroke.colorGreen = strokeData.colorGreen
                stroke.colorBlue = strokeData.colorBlue
                stroke.colorAlpha = strokeData.colorAlpha
                stroke.layer = layer
                layer.drawingStrokes.append(stroke)
                modelContext.insert(stroke)
            }
        }

        // Ensure background layer exists (backward compatibility with older exports)
        if project.backgroundLayer == nil {
            let bgLayer = MapLayer(
                name: "Background",
                sortOrder: -1,
                layerTypeRaw: LayerType.background.rawValue
            )
            bgLayer.opacity = exportModel.project.backgroundOpacity ?? 0.3
            bgLayer.isLocked = true
            project.layers.append(bgLayer)
            modelContext.insert(bgLayer)
        }

        // Ensure grid layer exists (backward compatibility with older exports)
        if project.gridLayer == nil {
            let gridLayer = MapLayer(
                name: "Grid",
                sortOrder: -2,
                layerTypeRaw: LayerType.grid.rawValue
            )
            gridLayer.isVisible = exportModel.project.showGridLines
            gridLayer.gridShowCoordinateLabels = exportModel.project.showCoordinateLabels
            gridLayer.isLocked = true
            gridLayer.opacity = 0.3
            project.layers.append(gridLayer)
            modelContext.insert(gridLayer)
        }

        try modelContext.save()

        if !imageRestoreFailures.isEmpty {
            logger.warning("Import completed with \(imageRestoreFailures.count) image restore failures: \(imageRestoreFailures.joined(separator: "; "))")
        }

        return project
    }
}
