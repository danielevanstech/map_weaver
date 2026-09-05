import SwiftUI

/// Floating overlay for editing a drawing stroke's color and line width.
struct StrokeEditorOverlay: View {
    @Bindable var stroke: DrawingStroke
    var onDismiss: () -> Void

    @State private var selectedColor: Color = .white
    @State private var lineWidth: Double = 2.0

    var body: some View {
        ZStack {
            // Dismiss backdrop
            Color.black.opacity(0.001)
                .ignoresSafeArea()
                .onTapGesture { commit() }

            VStack(spacing: 12) {
                Text("Edit Stroke")
                    .font(.headline)

                HStack(spacing: 16) {
                    ColorPicker("Color", selection: $selectedColor)

                    Spacer()
                }

                HStack(spacing: 8) {
                    Text("Width")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Slider(value: $lineWidth, in: 1...20)
                    Text("\(Int(lineWidth))")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 24)
                }

                HStack {
                    Spacer()
                    Button("Done") {
                        commit()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            .frame(width: 280)
            .shadow(color: .black.opacity(0.3), radius: 12, y: 4)
        }
        .onAppear { loadStroke() }
    }

    private func loadStroke() {
        selectedColor = Color(
            red: stroke.colorRed,
            green: stroke.colorGreen,
            blue: stroke.colorBlue,
            opacity: stroke.colorAlpha
        )
        lineWidth = stroke.lineWidth
    }

    private func commit() {
        let uiColor = UIColor(selectedColor)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        stroke.colorRed = Double(r)
        stroke.colorGreen = Double(g)
        stroke.colorBlue = Double(b)
        stroke.colorAlpha = Double(a)
        stroke.lineWidth = lineWidth
        onDismiss()
    }
}
