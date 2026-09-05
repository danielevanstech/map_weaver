import SwiftUI

/// Compact toolbar shown when a text layer is active.
/// Provides mode switching (Add / Select / Edit), color/size defaults, and delete.
struct TextToolbar: View {
    @Bindable var viewModel: MapEditorViewModel
    var onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Mode buttons
            HStack(spacing: 4) {
                modeButton(.add, icon: "plus.circle", label: "Add")
                modeButton(.select, icon: "hand.tap", label: "Select")
                modeButton(.edit, icon: "pencil", label: "Edit")
            }

            Divider().frame(height: 28)

            // Default color for new/edited text
            ColorPicker("", selection: textColorBinding)
                .labelsHidden()
                .frame(width: 36)

            Divider().frame(height: 28)

            // Default font size
            HStack(spacing: 4) {
                Image(systemName: "textformat.size")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Stepper("\(Int(viewModel.newTextFontSize))", value: $viewModel.newTextFontSize, in: 8...72, step: 2)
                    .font(.caption)
                    .fixedSize()
            }

            Spacer()

            // Delete selected annotation
            if viewModel.selectedTextAnnotation != nil {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 20))
                        .frame(minWidth: 44, minHeight: 44)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    // MARK: - Mode Button

    @ViewBuilder
    private func modeButton(_ mode: MapEditorViewModel.TextToolMode, icon: String, label: String) -> some View {
        Button {
            viewModel.textToolMode = mode
            if mode != .select {
                viewModel.clearSelection()
            }
        } label: {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                Text(label)
                    .font(.system(size: 9))
            }
            .frame(minWidth: 44, minHeight: 44)
        }
        .tint(viewModel.textToolMode == mode ? .blue : .secondary)
    }

    // MARK: - Color Binding

    private var textColorBinding: Binding<Color> {
        Binding(
            get: {
                Color(
                    red: viewModel.newTextColorRed,
                    green: viewModel.newTextColorGreen,
                    blue: viewModel.newTextColorBlue,
                    opacity: viewModel.newTextColorAlpha
                )
            },
            set: { newColor in
                let uiColor = UIColor(newColor)
                var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
                viewModel.newTextColorRed = Double(r)
                viewModel.newTextColorGreen = Double(g)
                viewModel.newTextColorBlue = Double(b)
                viewModel.newTextColorAlpha = Double(a)
            }
        )
    }
}
