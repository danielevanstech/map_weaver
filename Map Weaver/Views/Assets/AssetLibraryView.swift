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

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
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
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 76), spacing: 10)], spacing: 10) {
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
            .navigationTitle("Tile Assets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        showingImport = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingImport) {
                AssetImportView(project: project)
            }
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
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color.secondary.opacity(0.2))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
    }
}
