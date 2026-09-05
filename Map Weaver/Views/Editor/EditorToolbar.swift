import SwiftUI
import SwiftData

struct EditorToolbar: View {
    @Bindable var viewModel: MapEditorViewModel
    var modelContext: ModelContext

    var body: some View {
        HStack(spacing: 16) {
            // Undo / Redo
            HStack(spacing: 12) {
                Button {
                    viewModel.undoService.undo(context: modelContext, viewModel: viewModel)
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 22))
                        .frame(minWidth: 44, minHeight: 44)
                }
                .disabled(!viewModel.undoService.canUndo)
                .accessibilityLabel("Undo")

                Button {
                    viewModel.undoService.redo(context: modelContext, viewModel: viewModel)
                } label: {
                    Image(systemName: "arrow.uturn.forward")
                        .font(.system(size: 22))
                        .frame(minWidth: 44, minHeight: 44)
                }
                .disabled(!viewModel.undoService.canRedo)
                .accessibilityLabel("Redo")
            }

            Spacer()

            // Zoom display — tappable to reset
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.zoomTowardCenter(newScale: 1.0)
                }
            } label: {
                Text("\(Int(viewModel.zoomScale * 100))%")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.primary)
            }
            .accessibilityLabel("Zoom \(Int(viewModel.zoomScale * 100)) percent. Tap to reset.")


        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }
}
