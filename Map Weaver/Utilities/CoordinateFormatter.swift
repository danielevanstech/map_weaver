import Foundation

enum CoordinateFormatter {
    /// Column label using x coordinate.
    static func columnLabel(_ col: Int) -> String {
        "\(col)"
    }

    /// Row label using y coordinate.
    static func rowLabel(_ row: Int) -> String {
        "\(row)"
    }

    /// Full coordinate label, e.g., "0,0", "3,5", "-1,2"
    static func label(col: Int, row: Int) -> String {
        "\(col),\(row)"
    }
}
