import SwiftUI

struct CropResizeView: View {
    let sourceImage: UIImage
    let project: MapProject
    let onComplete: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var assetName = ""
    @State private var category = "Ground"
    @State private var gridWidth = 1
    @State private var gridHeight = 1

    @State private var cropRect: CGRect = .zero
    @State private var imageDisplaySize: CGSize = .zero
    @State private var useAutoFit = false

    @State private var isSaving = false

    private let predefinedCategories = ["Ground", "Walls", "Trees", "Enemies", "Items", "Effects"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Image preview with crop rect
                    imagePreview
                        .padding(.horizontal)

                    // Grid size picker
                    gridSizePicker
                        .padding(.horizontal)

                    // Auto-fit toggle
                    Toggle("Auto-Fit (center crop to fill)", isOn: $useAutoFit)
                        .padding(.horizontal)

                    Divider()

                    // Asset metadata
                    VStack(alignment: .leading, spacing: 12) {
                        TextField("Asset Name", text: $assetName)
                            .textFieldStyle(.roundedBorder)

                        Picker("Category", selection: $category) {
                            ForEach(predefinedCategories, id: \.self) { cat in
                                Text(cat).tag(cat)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    .padding(.horizontal)

                    // Save button
                    Button {
                        saveAsset()
                    } label: {
                        if isSaving {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding()
                        } else {
                            Text("Save Tile Asset")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding()
                        }
                    }
                    .background(canSave ? Color.blue : Color.gray)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .disabled(!canSave || isSaving)
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Crop & Resize")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                assetName = "Tile \(project.assets.count + 1)"
            }
        }
    }

    // MARK: - Image Preview

    private var imagePreview: some View {
        GeometryReader { geometry in
            let containerWidth = geometry.size.width
            let imageAspect = sourceImage.size.width / sourceImage.size.height
            let displayWidth = containerWidth
            let displayHeight = displayWidth / imageAspect

            Image(uiImage: sourceImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: displayWidth, height: displayHeight)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )
                .onAppear {
                    imageDisplaySize = CGSize(width: displayWidth, height: displayHeight)
                }
        }
        .aspectRatio(sourceImage.size.width / sourceImage.size.height, contentMode: .fit)
    }

    // MARK: - Grid Size Picker

    private var gridSizePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tile Grid Size")
                .font(.subheadline)
                .fontWeight(.medium)

            HStack(spacing: 16) {
                VStack {
                    Text("Width")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Stepper("\(gridWidth)", value: $gridWidth, in: 1...10)
                        .labelsHidden()
                    Text("\(gridWidth) cell\(gridWidth > 1 ? "s" : "")")
                        .font(.caption2)
                }

                Text("\u{00D7}")
                    .font(.title2)
                    .foregroundStyle(.secondary)

                VStack {
                    Text("Height")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Stepper("\(gridHeight)", value: $gridHeight, in: 1...10)
                        .labelsHidden()
                    Text("\(gridHeight) cell\(gridHeight > 1 ? "s" : "")")
                        .font(.caption2)
                }
            }

            // Quick presets
            HStack(spacing: 8) {
                ForEach([(1, 1), (2, 1), (1, 2), (2, 2), (3, 3)], id: \.0) { w, h in
                    Button("\(w)x\(h)") {
                        gridWidth = w
                        gridHeight = h
                    }
                    .buttonStyle(.bordered)
                    .tint(gridWidth == w && gridHeight == h ? .blue : .secondary)
                    .font(.caption)
                }
            }
        }
    }

    // MARK: - Validation

    private var canSave: Bool {
        !assetName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Save

    private func saveAsset() {
        guard canSave else { return }
        isSaving = true

        let cellSize = CGFloat(project.gridCellSize)
        let targetSize = CGSize(
            width: cellSize * CGFloat(gridWidth),
            height: cellSize * CGFloat(gridHeight)
        )

        // Process the image
        let processedImage: UIImage
        if useAutoFit {
            processedImage = sourceImage.autoFit(to: targetSize)
        } else {
            processedImage = sourceImage.resized(to: targetSize)
        }

        // Create the asset
        let assetID = UUID()
        let trimmedName = assetName.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            let relativePath = try ImageStore.shared.save(
                image: processedImage,
                projectID: project.id,
                assetID: assetID
            )

            let asset = TileAsset(
                name: trimmedName,
                imageFileName: relativePath,
                category: category,
                gridWidth: gridWidth,
                gridHeight: gridHeight,
                hasTransparency: processedImage.hasAlphaChannel
            )
            asset.id = assetID
            project.assets.append(asset)
            modelContext.insert(asset)
            project.modifiedAt = Date()

            try modelContext.save()

            onComplete()
        } catch {
            print("Failed to save asset: \(error)")
            isSaving = false
        }
    }
}
