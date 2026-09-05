import Foundation

/// Distinguishes the kinds of layers in a MapProject.
enum LayerType: Int, Codable, CaseIterable {
    case tile = 0
    case drawing = 1
    case text = 2
    case background = 3
    case grid = 4

    var displayName: String {
        switch self {
        case .tile: return "Tile"
        case .drawing: return "Drawing"
        case .text: return "Text"
        case .background: return "Background"
        case .grid: return "Grid"
        }
    }

    var iconName: String {
        switch self {
        case .tile: return "square.grid.2x2"
        case .drawing: return "pencil.tip"
        case .text: return "textformat"
        case .background: return "photo"
        case .grid: return "grid"
        }
    }
}
