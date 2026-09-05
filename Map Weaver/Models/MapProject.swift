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
    /// Deprecated: Use gridLayer.isVisible instead. Kept for schema compatibility.
    var showGridLines: Bool
    /// Deprecated: Use gridLayer.gridShowCoordinateLabels instead. Kept for schema compatibility.
    var showCoordinateLabels: Bool
    /// Deprecated: Use gridLayer color properties instead. Kept for schema compatibility.
    var gridLinesBlack: Bool

    /// Relative path to a decorative background image stored in Documents/BackgroundImages/
    var backgroundImageFileName: String?
    /// Raw value of BackgroundDisplayMode. Defaults to 1 (stretchToFit) for cross-device compatibility.
    var backgroundDisplayModeRaw: Int
    /// Background image opacity from 0.0 to 1.0. Deprecated: use backgroundLayer.opacity instead.
    var backgroundOpacity: Double

    /// Type-safe access to the background display mode.
    var backgroundDisplayMode: BackgroundDisplayMode {
        get { BackgroundDisplayMode(rawValue: backgroundDisplayModeRaw) ?? .stretchToFit }
        set { backgroundDisplayModeRaw = newValue.rawValue }
    }

    /// Returns the background layer if one exists.
    var backgroundLayer: MapLayer? {
        layers.first { $0.layerType == .background }
    }

    /// Returns the grid layer if one exists.
    var gridLayer: MapLayer? {
        layers.first { $0.layerType == .grid }
    }

    var folder: ProjectFolder?

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
        self.gridLinesBlack = false
        self.backgroundImageFileName = nil
        self.backgroundDisplayModeRaw = BackgroundDisplayMode.stretchToFit.rawValue
        self.backgroundOpacity = 0.3
        self.layers = []
        self.assets = []
    }
}
