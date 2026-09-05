import SwiftUI

struct ExportMenuView: View {
    let project: MapProject
    @Environment(\.dismiss) private var dismiss

    @State private var isExporting = false
    @State private var exportError: String?
    @State private var exportedFileURL: URL?
    @State private var showingShareSheet = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        exportPDF()
                    } label: {
                        Label {
                            VStack(alignment: .leading) {
                                Text("PDF Document")
                                    .font(.subheadline)
                                Text("High-quality vector output for printing")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "doc.richtext")
                                .foregroundStyle(.red)
                        }
                    }

                    Button {
                        exportJPEG()
                    } label: {
                        Label {
                            VStack(alignment: .leading) {
                                Text("JPEG Image")
                                    .font(.subheadline)
                                Text("Raster image for sharing and viewing")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "photo")
                                .foregroundStyle(.blue)
                        }
                    }

                    Button {
                        exportBundle()
                    } label: {
                        Label {
                            VStack(alignment: .leading) {
                                Text("Map Weaver Bundle (.mapweaver)")
                                    .font(.subheadline)
                                Text("Includes all data and images for sharing or backup")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "archivebox")
                                .foregroundStyle(.green)
                        }
                    }
                } header: {
                    Text("Export Format")
                }

                if let error = exportError {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Export Map")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .overlay {
                if isExporting {
                    ZStack {
                        Color.black.opacity(0.3)
                        ProgressView("Exporting...")
                            .padding()
                            .background(.regularMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .ignoresSafeArea()
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                if let url = exportedFileURL {
                    ShareSheetView(items: [url])
                }
            }
        }
    }

    // MARK: - Export Actions

    private func exportPDF() {
        isExporting = true
        exportError = nil

        let proj = project
        Task { @MainActor in
            let data = ExportService.exportPDF(project: proj)
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("\(proj.name).pdf")
            try? data.write(to: tempURL)

            isExporting = false
            exportedFileURL = tempURL
            showingShareSheet = true
        }
    }

    private func exportJPEG() {
        isExporting = true
        exportError = nil

        let proj = project
        Task { @MainActor in
            let data = ExportService.exportJPEG(project: proj)
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("\(proj.name).jpg")
            try? data.write(to: tempURL)

            isExporting = false
            exportedFileURL = tempURL
            showingShareSheet = true
        }
    }

    private func exportBundle() {
        isExporting = true
        exportError = nil

        let proj = project
        Task { @MainActor in
            do {
                let url = try ExportService.exportBundle(project: proj)
                isExporting = false
                exportedFileURL = url
                showingShareSheet = true
            } catch {
                isExporting = false
                exportError = error.localizedDescription
            }
        }
    }
}

// MARK: - Share Sheet

struct ShareSheetView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
