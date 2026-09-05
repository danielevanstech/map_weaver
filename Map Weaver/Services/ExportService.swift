import UIKit
import SwiftData

/// Handles exporting maps to PDF, JPEG, and .mapweaver (JSON + ZIP) formats.
enum ExportService {

    // MARK: - Map Bounds

    struct MapBounds {
        let minX: Int
        let maxX: Int
        let minY: Int
        let maxY: Int

        var width: Int { maxX - minX + 1 }
        var height: Int { maxY - minY + 1 }

        static let empty = MapBounds(minX: 0, maxX: 0, minY: 0, maxY: 0)
    }

    static func computeMapBounds(project: MapProject) -> MapBounds {
        var allTiles: [PlacedTile] = []
        for layer in project.layers {
            allTiles.append(contentsOf: layer.placedTiles)
        }

        guard !allTiles.isEmpty else { return .empty }

        let minX = allTiles.map(\.gridX).min()!
        let maxX = allTiles.map(\.gridX).max()!
        let minY = allTiles.map(\.gridY).min()!
        let maxY = allTiles.map(\.gridY).max()!

        return MapBounds(minX: minX, maxX: maxX, minY: minY, maxY: maxY)
    }

    // MARK: - Render Tiles

    private static func renderTiles(
        project: MapProject,
        bounds: MapBounds,
        cellSize: CGFloat,
        in cgContext: CGContext
    ) {
        let sortedLayers = project.layers.sorted { $0.sortOrder < $1.sortOrder }

        for layer in sortedLayers {
            guard layer.isVisible else { continue }

            cgContext.setAlpha(layer.opacity)

            for tile in layer.placedTiles {
                guard let asset = tile.asset else { continue }

                let x = CGFloat(tile.gridX - bounds.minX) * cellSize
                let y = CGFloat(tile.gridY - bounds.minY) * cellSize
                let rect = CGRect(x: x, y: y, width: cellSize, height: cellSize)

                if let image = ImageCache.shared.image(for: asset) {
                    image.draw(in: rect)
                }
            }

            cgContext.setAlpha(1.0)
        }

        // Draw grid if enabled
        if project.showGridLines {
            drawGridForExport(
                bounds: bounds,
                cellSize: cellSize,
                in: cgContext,
                showLabels: project.showCoordinateLabels
            )
        }
    }

    private static func drawGridForExport(
        bounds: MapBounds,
        cellSize: CGFloat,
        in cgContext: CGContext,
        showLabels: Bool
    ) {
        cgContext.setStrokeColor(UIColor.gray.withAlphaComponent(0.3).cgColor)
        cgContext.setLineWidth(0.5)

        let totalWidth = CGFloat(bounds.width) * cellSize
        let totalHeight = CGFloat(bounds.height) * cellSize

        // Vertical lines
        for col in 0...bounds.width {
            let x = CGFloat(col) * cellSize
            cgContext.move(to: CGPoint(x: x, y: 0))
            cgContext.addLine(to: CGPoint(x: x, y: totalHeight))
        }

        // Horizontal lines
        for row in 0...bounds.height {
            let y = CGFloat(row) * cellSize
            cgContext.move(to: CGPoint(x: 0, y: y))
            cgContext.addLine(to: CGPoint(x: totalWidth, y: y))
        }

        cgContext.strokePath()

        // Coordinate labels
        if showLabels {
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: max(8, cellSize * 0.15), weight: .medium),
                .foregroundColor: UIColor.gray.withAlphaComponent(0.6)
            ]

            for col in 0..<bounds.width {
                let label = CoordinateFormatter.columnLabel(bounds.minX + col) as NSString
                let x = CGFloat(col) * cellSize + 2
                label.draw(at: CGPoint(x: x, y: 1), withAttributes: attributes)
            }

            for row in 0..<bounds.height {
                let label = CoordinateFormatter.rowLabel(bounds.minY + row) as NSString
                let y = CGFloat(row) * cellSize + 2
                label.draw(at: CGPoint(x: 1, y: y), withAttributes: attributes)
            }
        }
    }

    // MARK: - PDF Export

    static func exportPDF(project: MapProject) -> Data {
        let bounds = computeMapBounds(project: project)
        let cellSize = CGFloat(project.gridCellSize)
        let width = CGFloat(bounds.width) * cellSize
        let height = CGFloat(bounds.height) * cellSize

        let pageRect = CGRect(x: 0, y: 0, width: max(width, 100), height: max(height, 100))
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        return renderer.pdfData { context in
            context.beginPage()
            renderTiles(project: project, bounds: bounds, cellSize: cellSize, in: context.cgContext)
        }
    }

    // MARK: - JPEG Export

    static func exportJPEG(project: MapProject) -> Data {
        let bounds = computeMapBounds(project: project)
        let cellSize = CGFloat(project.gridCellSize)
        let size = CGSize(
            width: max(CGFloat(bounds.width) * cellSize, 100),
            height: max(CGFloat(bounds.height) * cellSize, 100)
        )

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.jpegData(withCompressionQuality: 0.9) { context in
            // Fill background
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            renderTiles(project: project, bounds: bounds, cellSize: cellSize, in: context.cgContext)
        }
    }

    // MARK: - .mapweaver Bundle Export (JSON + ZIP)

    static func exportBundle(project: MapProject) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("mapweaver-export-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        // Build export model
        let exportModel = MapExportModel(project: project)
        let jsonData = try JSONEncoder().encode(exportModel)
        try jsonData.write(to: tempDir.appendingPathComponent("map.json"))

        // Copy images
        let imagesDir = tempDir.appendingPathComponent("images")
        try FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true)

        for asset in project.assets {
            let sourceURL = ImageStore.shared.url(for: asset)
            let destURL = imagesDir.appendingPathComponent("\(asset.id.uuidString).png")
            if FileManager.default.fileExists(atPath: sourceURL.path) {
                try FileManager.default.copyItem(at: sourceURL, to: destURL)
            }
        }

        // ZIP using NSFileCoordinator
        let zipURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(project.name).mapweaver")

        // Remove existing file if any
        if FileManager.default.fileExists(atPath: zipURL.path) {
            try FileManager.default.removeItem(at: zipURL)
        }

        var coordinatorError: NSError?
        var resultURL: URL?

        let coordinator = NSFileCoordinator()
        coordinator.coordinate(
            readingItemAt: tempDir,
            options: .forUploading,
            error: &coordinatorError
        ) { actualZipURL in
            do {
                try FileManager.default.copyItem(at: actualZipURL, to: zipURL)
                resultURL = zipURL
            } catch {
                print("Failed to copy ZIP: \(error)")
            }
        }

        // Clean up temp directory
        try? FileManager.default.removeItem(at: tempDir)

        if let error = coordinatorError {
            throw error
        }

        guard let finalURL = resultURL else {
            throw ExportError.zipFailed
        }

        return finalURL
    }
}

// MARK: - Export Errors

enum ExportError: LocalizedError {
    case zipFailed
    case importFailed(String)

    var errorDescription: String? {
        switch self {
        case .zipFailed: return "Failed to create ZIP archive."
        case .importFailed(let reason): return "Import failed: \(reason)"
        }
    }
}

// MARK: - Codable Export Models

struct MapExportModel: Codable {
    let version: Int
    let project: ProjectExportData
    let layers: [LayerExportData]
    let assets: [AssetExportData]
    let tiles: [TileExportData]

    init(project: MapProject) {
        self.version = 1
        self.project = ProjectExportData(
            name: project.name,
            gridCellSize: project.gridCellSize,
            showGridLines: project.showGridLines,
            showCoordinateLabels: project.showCoordinateLabels
        )
        self.layers = project.layers.map { layer in
            LayerExportData(
                id: layer.id.uuidString,
                name: layer.name,
                sortOrder: layer.sortOrder,
                isVisible: layer.isVisible,
                isLocked: layer.isLocked,
                opacity: layer.opacity
            )
        }
        self.assets = project.assets.map { asset in
            AssetExportData(
                id: asset.id.uuidString,
                name: asset.name,
                imageFile: "images/\(asset.id.uuidString).png",
                gridWidth: asset.gridWidth,
                gridHeight: asset.gridHeight,
                hasTransparency: asset.hasTransparency,
                category: asset.category
            )
        }
        self.tiles = project.layers.flatMap { layer in
            layer.placedTiles.compactMap { tile in
                guard let assetID = tile.asset?.id else { return nil }
                return TileExportData(
                    gridX: tile.gridX,
                    gridY: tile.gridY,
                    layerId: layer.id.uuidString,
                    assetId: assetID.uuidString
                )
            }
        }
    }
}

struct ProjectExportData: Codable {
    let name: String
    let gridCellSize: Int
    let showGridLines: Bool
    let showCoordinateLabels: Bool
}

struct LayerExportData: Codable {
    let id: String
    let name: String
    let sortOrder: Int
    let isVisible: Bool
    let isLocked: Bool
    let opacity: Double
}

struct AssetExportData: Codable {
    let id: String
    let name: String
    let imageFile: String
    let gridWidth: Int
    let gridHeight: Int
    let hasTransparency: Bool
    let category: String
}

struct TileExportData: Codable {
    let gridX: Int
    let gridY: Int
    let layerId: String
    let assetId: String
}
