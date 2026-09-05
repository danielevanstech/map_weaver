import SwiftUI

/// Compact toolbar shown when a text layer is active.
/// Provides mode switching (Add / Move / Edit) and color/size defaults.
struct TextToolbar: View {
    @Bindable var viewModel: MapEditorViewModel

    var body: some View {
        HStack(spacing: 12) {
            // Add new text annotation
            Button {
                viewModel.clearSelection()
                createNewAnnotation()
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 18))
                    Text("Add")
                        .font(.system(size: 9))
                }
                .frame(minWidth: 44, minHeight: 44)
            }
            .tint(.secondary)

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
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    // MARK: - Create New Annotation

    private func createNewAnnotation() {
        let centerX = (viewModel.canvasSize.width / 2 - viewModel.panOffset.width) / viewModel.zoomScale
        let centerY = (viewModel.canvasSize.height / 2 - viewModel.panOffset.height) / viewModel.zoomScale
        let annotation = TextAnnotation(canvasX: Double(centerX), canvasY: Double(centerY), text: "")
        annotation.colorRed = viewModel.newTextColorRed
        annotation.colorGreen = viewModel.newTextColorGreen
        annotation.colorBlue = viewModel.newTextColorBlue
        annotation.colorAlpha = viewModel.newTextColorAlpha
        annotation.fontSize = viewModel.newTextFontSize
        viewModel.editingTextAnnotation = annotation
        viewModel.isNewTextAnnotation = true
        viewModel.textEditorPosition = CGPoint(x: viewModel.canvasSize.width / 2, y: viewModel.canvasSize.height / 2)
        viewModel.isShowingTextEditor = true
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
