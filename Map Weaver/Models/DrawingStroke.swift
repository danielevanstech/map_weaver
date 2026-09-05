import Foundation
import SwiftData

/// A single point in a drawing stroke with optional pressure.
struct StrokePoint: Codable {
    let x: Double
    let y: Double
    /// 0.0 to 1.0. Default 1.0 for finger; Apple Pencil provides actual force.
    let pressure: Double
}

@Model
final class DrawingStroke {
    var id: UUID
    /// JSON-encoded array of StrokePoint. SwiftData can't store struct arrays directly.
    var pointsData: Data
    /// RGBA color components
    var colorRed: Double
    var colorGreen: Double
    var colorBlue: Double
    var colorAlpha: Double
    /// Base line width in canvas units
    var lineWidth: Double

    var layer: MapLayer?

    /// Decoded stroke points.
    var points: [StrokePoint] {
        get {
            (try? JSONDecoder().decode([StrokePoint].self, from: pointsData)) ?? []
        }
        set {
            pointsData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }

    init(points: [StrokePoint], lineWidth: Double = 3.0) {
        self.id = UUID()
        self.pointsData = (try? JSONEncoder().encode(points)) ?? Data()
        self.lineWidth = lineWidth
        self.colorRed = 1.0
        self.colorGreen = 1.0
        self.colorBlue = 1.0
        self.colorAlpha = 1.0
    }
}
