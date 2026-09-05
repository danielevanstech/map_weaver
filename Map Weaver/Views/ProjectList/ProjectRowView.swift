import SwiftUI

struct ProjectRowView: View {
    let project: MapProject

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(project.name)
                .font(.headline)

            HStack(spacing: 12) {
                Label("\(project.layers.count) layers", systemImage: "square.3.layers.3d")
                Label("\(tileCount) tiles", systemImage: "square.grid.2x2")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Text("Modified \(project.modifiedAt, format: .relative(presentation: .named))")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    private var tileCount: Int {
        project.layers.reduce(0) { $0 + $1.placedTiles.count }
    }
}
