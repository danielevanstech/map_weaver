import Foundation

/// A hashable grid coordinate used as dictionary keys for O(1) tile lookup.
struct GridPosition: Hashable, Sendable {
    let x: Int
    let y: Int
}
