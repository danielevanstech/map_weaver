import SwiftUI

struct AssetTrayItemView: View {
    let asset: TileAsset
    let isSelected: Bool
    var showLabel: Bool = true

    @State private var thumbnail: UIImage?

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                if let thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 60, height: 60)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(width: 60, height: 60)
                        .overlay {
                            Image(systemName: "photo")
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2.5)
            )

            if showLabel {
                if isSelected {
                    Text(asset.name)
                        .font(.system(size: 10))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .frame(width: 60)
                } else {
                    Text("\(asset.gridWidth)×\(asset.gridHeight)")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .frame(width: 60)
                }
            }
        }
        .task {
            thumbnail = ImageStore.shared.loadImage(for: asset)
        }
    }
}
