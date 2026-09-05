import SwiftUI

struct AssetLibraryView: View {
    let project: MapProject
    @Binding var selectedAsset: TileAsset?

    @State private var showingImport = false
    @State private var selectedCategory: String?

    private var categories: [String] {
        let cats = Set(project.assets.map(\.category))
        return cats.sorted()
    }

    private var filteredAssets: [TileAsset] {
        if let category = selectedCategory {
            return project.assets.filter { $0.category == category }
        }
        return project.assets.sorted { $0.createdAt < $1.createdAt }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Tile Assets")
                    .font(.headline)
                Spacer()
                Button {
                    showingImport = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            // Category filter
            if !categories.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        CategoryChip(title: "All", isSelected: selectedCategory == nil) {
                            selectedCategory = nil
                        }
                        ForEach(categories, id: \.self) { category in
                            CategoryChip(title: category, isSelected: selectedCategory == category) {
                                selectedCategory = category
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 8)
            }

            // Asset grid
            if filteredAssets.isEmpty {
                ContentUnavailableView {
                    Label("No Assets", systemImage: "photo.on.rectangle")
                } description: {
                    Text("Import photos to use as map tiles.")
                }
                .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 60), spacing: 8)], spacing: 8) {
                        ForEach(filteredAssets) { asset in
                            AssetThumbnailView(asset: asset, isSelected: selectedAsset?.id == asset.id)
                                .onTapGesture {
                                    selectedAsset = asset
                                }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .sheet(isPresented: $showingImport) {
            AssetImportView(project: project)
        }
    }
}

struct CategoryChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue : Color.secondary.opacity(0.2))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
    }
}
