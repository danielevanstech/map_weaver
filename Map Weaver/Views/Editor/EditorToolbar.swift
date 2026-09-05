import SwiftUI
import SwiftData

struct EditorToolbar: View {
    @Bindable var viewModel: MapEditorViewModel
    var modelContext: ModelContext

    var body: some View {
        HStack(spacing: 16) {
            // Tool picker
            HStack(spacing: 4) {
                ForEach(EditorTool.allCases) { tool in
                    Button {
                        viewModel.selectedTool = tool
                    } label: {
                        Image(systemName: tool.systemImage)
                            .font(.system(size: 18))
                            .frame(width: 36, height: 36)
                            .background(
                                viewModel.selectedTool == tool
                                    ? Color.accentColor.opacity(0.2)
                                    : Color.clear
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .foregroundStyle(viewModel.selectedTool == tool ? .blue : .primary)
                    }
                    .accessibilityLabel(tool.rawValue)
                }
            }

            Spacer()

            // Undo / Redo
            HStack(spacing: 8) {
                Button {
                    viewModel.undoService.undo(context: modelContext, viewModel: viewModel)
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 16))
                }
                .disabled(!viewModel.undoService.canUndo)
                .accessibilityLabel("Undo")

                Button {
                    viewModel.undoService.redo(context: modelContext, viewModel: viewModel)
                } label: {
                    Image(systemName: "arrow.uturn.forward")
                        .font(.system(size: 16))
                }
                .disabled(!viewModel.undoService.canRedo)
                .accessibilityLabel("Redo")
            }

            Spacer()

            // Zoom display — tappable to reset
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.zoomScale = 1.0
                    viewModel.lastZoomScale = 1.0
                }
            } label: {
                Text("\(Int(viewModel.zoomScale * 100))%")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.primary)
            }
            .accessibilityLabel("Zoom \(Int(viewModel.zoomScale * 100)) percent. Tap to reset.")

            // View options menu (grid toggles + zoom controls)
            Menu {
                Section("Zoom") {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.zoomScale = min(viewModel.zoomScale * 1.5, MapEditorViewModel.maxZoom)
                            viewModel.lastZoomScale = viewModel.zoomScale
                        }
                    } label: {
                        Label("Zoom In", systemImage: "plus.magnifyingglass")
                    }

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.zoomScale = max(viewModel.zoomScale / 1.5, MapEditorViewModel.minZoom)
                            viewModel.lastZoomScale = viewModel.zoomScale
                        }
                    } label: {
                        Label("Zoom Out", systemImage: "minus.magnifyingglass")
                    }

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.zoomScale = 1.0
                            viewModel.lastZoomScale = 1.0
                        }
                    } label: {
                        Label("Reset Zoom", systemImage: "1.magnifyingglass")
                    }
                }

                Section("Grid") {
                    Toggle(isOn: Bindable(viewModel).project.showGridLines) {
                        Label("Grid Lines", systemImage: "grid")
                    }

                    Toggle(isOn: Bindable(viewModel).project.showCoordinateLabels) {
                        Label("Coordinate Labels", systemImage: "textformat.abc")
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 18))
            }
            .accessibilityLabel("View Options")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }
}
