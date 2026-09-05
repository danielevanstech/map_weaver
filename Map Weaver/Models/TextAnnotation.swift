import Foundation
import SwiftData

@Model
final class TextAnnotation {
    var id: UUID
    /// Canvas X coordinate (same coordinate space as grid pixel positions)
    var canvasX: Double
    /// Canvas Y coordinate
    var canvasY: Double
    /// The text content
    var text: String
    /// Font size in canvas units (scales with zoom)
    var fontSize: Double
    /// RGBA color components
    var colorRed: Double
    var colorGreen: Double
    var colorBlue: Double
    var colorAlpha: Double

    var layer: MapLayer?

    init(canvasX: Double, canvasY: Double, text: String, fontSize: Double = 16.0) {
        self.id = UUID()
        self.canvasX = canvasX
        self.canvasY = canvasY
        self.text = text
        self.fontSize = fontSize
        self.colorRed = 1.0
        self.colorGreen = 1.0
        self.colorBlue = 1.0
        self.colorAlpha = 1.0
    }
}
