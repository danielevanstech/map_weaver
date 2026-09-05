import SwiftUI
import PhotosUI

struct AssetImportView: View {
    let project: MapProject
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPhotosItem: PhotosPickerItem?
    @State private var importedImage: UIImage?
    @State private var showingCamera = false
    @State private var showingCropView = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Import a Tile Image")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.top)

                Text("Choose a source for your tile asset. PNG images with transparency are supported for overlay tiles.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                VStack(spacing: 16) {
                    PhotosPicker(selection: $selectedPhotosItem, matching: .images) {
                        Label("Choose from Photo Library", systemImage: "photo.on.rectangle")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    Button {
                        showingCamera = true
                    } label: {
                        Label("Take a Photo", systemImage: "camera")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal, 32)

                Spacer()
            }
            .navigationTitle("Import Asset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onChange(of: selectedPhotosItem) { _, newItem in
                Task {
                    await loadFromPhotoPicker(item: newItem)
                }
            }
            .sheet(isPresented: $showingCamera) {
                CameraView(image: $importedImage)
            }
            .onChange(of: importedImage) { _, newImage in
                if newImage != nil {
                    showingCropView = true
                }
            }
            .sheet(isPresented: $showingCropView) {
                if let image = importedImage {
                    CropResizeView(
                        sourceImage: image,
                        project: project
                    ) {
                        importedImage = nil
                        dismiss()
                    }
                }
            }
        }
    }

    private func loadFromPhotoPicker(item: PhotosPickerItem?) async {
        guard let item else { return }
        do {
            if let data = try await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                importedImage = image
            }
        } catch {
            print("Failed to load image from picker: \(error)")
        }
    }
}

// MARK: - Camera View (UIImagePickerController wrapper)

struct CameraView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraView

        init(_ parent: CameraView) {
            self.parent = parent
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let uiImage = info[.originalImage] as? UIImage {
                parent.image = uiImage
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
