import Foundation

/// How the background image is displayed on the canvas.
enum BackgroundDisplayMode: Int, Codable, CaseIterable {
    case originalSize = 0
    case stretchToFit = 1
    case aspectFit = 2
    case aspectFill = 3

    var displayName: String {
        switch self {
        case .originalSize: return "Original Size"
        case .stretchToFit: return "Stretch to Fit"
        case .aspectFit: return "Aspect Fit"
        case .aspectFill: return "Aspect Fill"
        }
    }
}
