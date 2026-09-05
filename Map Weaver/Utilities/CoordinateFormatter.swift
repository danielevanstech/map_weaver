import Foundation

enum CoordinateFormatter {
    /// Converts a zero-based column index to alphabetic label.
    /// 0 = "A", 1 = "B", ..., 25 = "Z", 26 = "AA", 27 = "AB", etc.
    /// Negative columns get a "-" prefix.
    static func columnLabel(_ col: Int) -> String {
        if col < 0 {
            return "-" + columnLabel(-col - 1)
        }
        var result = ""
        var n = col
        repeat {
            result = String(UnicodeScalar(65 + n % 26)!) + result
            n = n / 26 - 1
        } while n >= 0
        return result
    }

    /// Converts a zero-based row index to a 1-based row label.
    /// Negative rows get a "-" prefix.
    static func rowLabel(_ row: Int) -> String {
        if row < 0 {
            return "-\(-row)"
        }
        return "\(row + 1)"
    }

    /// Full coordinate label, e.g., "A1", "B3", "AA12"
    static func label(col: Int, row: Int) -> String {
        "\(columnLabel(col))\(rowLabel(row))"
    }
}
