import SwiftUI

struct FolderRowView: View {
    let folder: ProjectFolder

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "folder.fill")
                .foregroundStyle(.blue)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text(folder.name)
                    .font(.headline)
                Text("\(folder.projects.count) map\(folder.projects.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
