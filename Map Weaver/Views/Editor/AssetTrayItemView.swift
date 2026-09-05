import SwiftUI

struct AssetTrayItemView: View {
    let asset: TileAsset
    let isSelected: Bool

    @State private var thumbnail: UIImage?

    var body: some View {
        ZStack {
            if let thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 48, height: 48)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 48, height: 48)
                    .overlay {
                        Image(systemName: "photo")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2.5)
        )
        .task {
            thumbnail = ImageStore.shared.loadImage(for: asset)
        }
    }
}
