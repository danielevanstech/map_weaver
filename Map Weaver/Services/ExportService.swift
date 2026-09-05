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
        let maxX = allTiles.map { $0.gridX + ($0.asset?.gridWidth ?? 1) - 1 }.max()!
        let minY = allTiles.map(\.gridY).min()!
        let maxY = allTiles.map { $0.gridY + ($0.asset?.gridHeight ?? 1) - 1 }.max()!

        return MapBounds(minX: minX, maxX: maxX, minY: minY, maxY: maxY)
    }

    // MARK: - Render Tiles

    private static func renderContent(
        project: MapProject,
        bounds: MapBounds,
        cellSize: CGFloat,
        in cgContext: CGContext
    ) {
        let sortedLayers = project.layers.sorted { $0.sortOrder < $1.sortOrder }

        for layer in sortedLayers {
            guard layer.isVisible else { continue }

            cgContext.setAlpha(layer.opacity)

            switch layer.layerType {
            case .tile:
                for tile in layer.placedTiles {
                    guard let asset = tile.asset else { continue }

                    let x = CGFloat(tile.gridX - bounds.minX) * cellSize
                    let y = CGFloat(tile.gridY - bounds.minY) * cellSize
                    let tw = CGFloat(asset.gridWidth) * cellSize
                    let th = CGFloat(asset.gridHeight) * cellSize
                    let rect = CGRect(x: x, y: y, width: tw, height: th)

                    if let image = ImageCache.shared.image(for: asset) {
                        image.draw(in: rect)
                    }
                }

            case .text:
                for annotation in layer.textAnnotations {
                    let x = CGFloat(annotation.canvasX) - CGFloat(bounds.minX) * cellSize
                    let y = CGFloat(annotation.canvasY) - CGFloat(bounds.minY) * cellSize
                    let color = UIColor(
                        red: annotation.colorRed,
                        green: annotation.colorGreen,
                        blue: annotation.colorBlue,
                        alpha: annotation.colorAlpha
                    )
                    let attributes: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: annotation.fontSize),
                        .foregroundColor: color
                    ]
                    (annotation.text as NSString).draw(at: CGPoint(x: x, y: y), withAttributes: attributes)
                }

            case .background, .grid:
                break // Background is screen-space; grid is rendered separately

            case .drawing:
                for stroke in layer.drawingStrokes {
                    let points = stroke.points
                    guard points.count >= 2 else { continue }

                    let color = UIColor(
                        red: stroke.colorRed,
                        green: stroke.colorGreen,
                        blue: stroke.colorBlue,
                        alpha: stroke.colorAlpha
                    )
                    cgContext.setStrokeColor(color.cgColor)
                    cgContext.setLineWidth(stroke.lineWidth)
                    cgContext.setLineCap(.round)
                    cgContext.setLineJoin(.round)

                    let first = points[0]
                    cgContext.move(to: CGPoint(
                        x: first.x - Double(bounds.minX) * Double(cellSize),
                        y: first.y - Double(bounds.minY) * Double(cellSize)
                    ))
                    for i in 1..<points.count {
                        cgContext.addLine(to: CGPoint(
                            x: points[i].x - Double(bounds.minX) * Double(cellSize),
                            y: points[i].y - Double(bounds.minY) * Double(cellSize)
                        ))
                    }
                    cgContext.strokePath()
                }
            }

            cgContext.setAlpha(1.0)
        }

        // Draw grid if enabled
        if let gridLayer = project.gridLayer, gridLayer.isVisible {
            cgContext.setAlpha(gridLayer.opacity)
            drawGridForExport(
                bounds: bounds,
                cellSize: cellSize,
                in: cgContext,
                gridLayer: gridLayer
            )
            cgContext.setAlpha(1.0)
        }
    }

    private static func drawGridForExport(
        bounds: MapBounds,
        cellSize: CGFloat,
        in cgContext: CGContext,
        gridLayer: MapLayer
    ) {
        let color = UIColor(
            red: gridLayer.gridColorRed,
            green: gridLayer.gridColorGreen,
            blue: gridLayer.gridColorBlue,
            alpha: gridLayer.gridColorAlpha
        )
        cgContext.setStrokeColor(color.cgColor)
        cgContext.setLineWidth(gridLayer.gridLineWidth)

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
        if gridLayer.gridShowCoordinateLabels {
            let labelColor = UIColor(
                red: gridLayer.gridColorRed,
                green: gridLayer.gridColorGreen,
                blue: gridLayer.gridColorBlue,
                alpha: gridLayer.gridColorAlpha * 0.7
            )
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: max(8, cellSize * 0.15), weight: .medium),
                .foregroundColor: labelColor
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
            renderContent(project: project, bounds: bounds, cellSize: cellSize, in: context.cgContext)
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
            renderContent(project: project, bounds: bounds, cellSize: cellSize, in: context.cgContext)
        }
    }

    // MARK: - .mapweaver Bundle Export (Self-Contained JSON with Embedded Images)

    static func exportBundle(project: MapProject) throws -> URL {
        let exportModel = MapExportModel(project: project)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let jsonData = try encoder.encode(exportModel)

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(project.name).mapweaver")

        if FileManager.default.fileExists(atPath: tempURL.path) {
            try FileManager.default.removeItem(at: tempURL)
        }

        try jsonData.write(to: tempURL)
        return tempURL
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
    let textAnnotations: [TextAnnotationExportData]?
    let drawingStrokes: [DrawingStrokeExportData]?

    init(project: MapProject) {
        self.version = 2
        self.project = ProjectExportData(
            name: project.name,
            gridCellSize: project.gridCellSize,
            showGridLines: project.showGridLines,
            showCoordinateLabels: project.showCoordinateLabels,
            backgroundDisplayModeRaw: project.backgroundDisplayModeRaw,
            backgroundOpacity: project.backgroundLayer?.opacity ?? project.backgroundOpacity
        )
        self.layers = project.layers.map { layer in
            LayerExportData(
                id: layer.id.uuidString,
                name: layer.name,
                sortOrder: layer.sortOrder,
                isVisible: layer.isVisible,
                isLocked: layer.isLocked,
                opacity: layer.opacity,
                layerTypeRaw: layer.layerTypeRaw,
                gridLineWidth: layer.layerType == .grid ? layer.gridLineWidth : nil,
                gridColorRed: layer.layerType == .grid ? layer.gridColorRed : nil,
                gridColorGreen: layer.layerType == .grid ? layer.gridColorGreen : nil,
                gridColorBlue: layer.layerType == .grid ? layer.gridColorBlue : nil,
                gridColorAlpha: layer.layerType == .grid ? layer.gridColorAlpha : nil,
                gridShowCoordinateLabels: layer.layerType == .grid ? layer.gridShowCoordinateLabels : nil
            )
        }
        self.assets = project.assets.map { asset in
            let imageBase64: String?
            if let image = ImageStore.shared.loadImage(for: asset),
               let pngData = image.pngData() {
                imageBase64 = pngData.base64EncodedString()
            } else {
                imageBase64 = nil
            }
            return AssetExportData(
                id: asset.id.uuidString,
                name: asset.name,
                imageFile: "images/\(asset.id.uuidString).png",
                imageData: imageBase64,
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
        self.textAnnotations = project.layers.flatMap { layer in
            layer.textAnnotations.map { annotation in
                TextAnnotationExportData(
                    canvasX: annotation.canvasX,
                    canvasY: annotation.canvasY,
                    text: annotation.text,
                    fontSize: annotation.fontSize,
                    colorRed: annotation.colorRed,
                    colorGreen: annotation.colorGreen,
                    colorBlue: annotation.colorBlue,
                    colorAlpha: annotation.colorAlpha,
                    layerId: layer.id.uuidString
                )
            }
        }
        self.drawingStrokes = project.layers.flatMap { layer in
            layer.drawingStrokes.map { stroke in
                DrawingStrokeExportData(
                    pointsData: stroke.pointsData.base64EncodedString(),
                    colorRed: stroke.colorRed,
                    colorGreen: stroke.colorGreen,
                    colorBlue: stroke.colorBlue,
                    colorAlpha: stroke.colorAlpha,
                    lineWidth: stroke.lineWidth,
                    layerId: layer.id.uuidString
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
    let backgroundDisplayModeRaw: Int?
    let backgroundOpacity: Double?
}

struct LayerExportData: Codable {
    let id: String
    let name: String
    let sortOrder: Int
    let isVisible: Bool
    let isLocked: Bool
    let opacity: Double
    let layerTypeRaw: Int?
    // Grid layer properties (nil for non-grid layers)
    let gridLineWidth: Double?
    let gridColorRed: Double?
    let gridColorGreen: Double?
    let gridColorBlue: Double?
    let gridColorAlpha: Double?
    let gridShowCoordinateLabels: Bool?
}

struct AssetExportData: Codable {
    let id: String
    let name: String
    let imageFile: String
    /// Base64-encoded PNG image data (embedded for portability)
    let imageData: String?
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

struct TextAnnotationExportData: Codable {
    let canvasX: Double
    let canvasY: Double
    let text: String
    let fontSize: Double
    let colorRed: Double
    let colorGreen: Double
    let colorBlue: Double
    let colorAlpha: Double
    let layerId: String
}

struct DrawingStrokeExportData: Codable {
    let pointsData: String
    let colorRed: Double
    let colorGreen: Double
    let colorBlue: Double
    let colorAlpha: Double
    let lineWidth: Double
    let layerId: String
}
