import SwiftUI

/// Compact toolbar shown when a drawing layer is active.
/// Provides drawing mode toggle, color picker, and line width control.
struct DrawingToolbar: View {
    @Bindable var viewModel: MapEditorViewModel

    var body: some View {
        HStack(spacing: 12) {
            // Drawing mode toggle
            Button {
                viewModel.isDrawingModeActive.toggle()
            } label: {
                Image(systemName: viewModel.isDrawingModeActive ? "pencil.tip.crop.circle.fill" : "pencil.tip.crop.circle")
                    .font(.system(size: 24))
                    .frame(minWidth: 44, minHeight: 44)
            }
            .tint(viewModel.isDrawingModeActive ? .blue : .secondary)
            .accessibilityLabel(viewModel.isDrawingModeActive ? "Drawing Mode On" : "Drawing Mode Off")

            Divider().frame(height: 28)

            // Stroke color
            ColorPicker("", selection: strokeColorBinding)
                .labelsHidden()
                .frame(width: 36)

            Divider().frame(height: 28)

            // Line width
            HStack(spacing: 4) {
                Image(systemName: "line.diagonal")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Slider(value: $viewModel.newStrokeLineWidth, in: 1...20)
                    .frame(width: 80)
                Text("\(Int(viewModel.newStrokeLineWidth))")
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
            }

            Spacer()

            Text("Drawing")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    // MARK: - Color Binding

    private var strokeColorBinding: Binding<Color> {
        Binding(
            get: {
                Color(
                    red: viewModel.newStrokeColorRed,
                    green: viewModel.newStrokeColorGreen,
                    blue: viewModel.newStrokeColorBlue,
                    opacity: viewModel.newStrokeColorAlpha
                )
            },
            set: { newColor in
                let uiColor = UIColor(newColor)
                var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
                viewModel.newStrokeColorRed = Double(r)
                viewModel.newStrokeColorGreen = Double(g)
                viewModel.newStrokeColorBlue = Double(b)
                viewModel.newStrokeColorAlpha = Double(a)
            }
        )
    }
}
