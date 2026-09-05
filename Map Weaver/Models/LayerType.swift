import Foundation

/// Distinguishes the three kinds of layers in a MapProject.
enum LayerType: Int, Codable, CaseIterable {
    case tile = 0
    case drawing = 1
    case text = 2

    var displayName: String {
        switch self {
        case .tile: return "Tile"
        case .drawing: return "Drawing"
        case .text: return "Text"
        }
    }

    var iconName: String {
        switch self {
        case .tile: return "square.grid.2x2"
        case .drawing: return "pencil.tip"
        case .text: return "textformat"
        }
    }
}
