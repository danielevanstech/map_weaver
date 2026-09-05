import SwiftUI

struct AssetTrayView: View {
    let project: MapProject
    @Bindable var viewModel: MapEditorViewModel
    var onOpenLibrary: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Open full library / import
                Button(action: onOpenLibrary) {
                    Image(systemName: "plus.square.dashed")
                        .font(.title2)
                        .frame(width: 48, height: 48)
                        .background(Color.secondary.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .accessibilityLabel("Open Asset Library")

                ForEach(project.assets.sorted(by: { $0.createdAt < $1.createdAt })) { asset in
                    AssetTrayItemView(
                        asset: asset,
                        isSelected: viewModel.traySelectedAsset?.id == asset.id
                    )
                    .onTapGesture {
                        if viewModel.traySelectedAsset?.id == asset.id {
                            viewModel.traySelectedAsset = nil
                        } else {
                            viewModel.traySelectedAsset = asset
                        }
                    }
                    .draggable(asset.id.uuidString) {
                        // Drag preview
                        AssetTrayItemView(asset: asset, isSelected: false)
                            .frame(width: 48, height: 48)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .frame(height: 60)
        .background(.ultraThinMaterial)
    }
}
