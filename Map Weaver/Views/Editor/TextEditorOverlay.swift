import SwiftUI
import SwiftData

/// Floating overlay for creating and editing text annotations on text layers.
struct TextEditorOverlay: View {
    @Bindable var viewModel: MapEditorViewModel
    @Environment(\.modelContext) private var modelContext

    @State private var textContent: String = ""
    @State private var selectedColor: Color = .white
    @State private var fontSize: Double = 16.0

    var body: some View {
        ZStack {
            // Dismiss backdrop
            Color.black.opacity(0.001)
                .ignoresSafeArea()
                .onTapGesture { cancel() }

            VStack(spacing: 12) {
                TextField("Enter text...", text: $textContent, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...5)

                HStack(spacing: 12) {
                    ColorPicker("", selection: $selectedColor)
                        .labelsHidden()
                        .frame(width: 30)

                    Stepper("Size: \(Int(fontSize))", value: $fontSize, in: 8...72, step: 2)
                        .font(.caption)

                    Spacer()

                    if let annotation = viewModel.editingTextAnnotation,
                       !viewModel.isNewTextAnnotation,
                       !annotation.text.isEmpty {
                        Button(role: .destructive) {
                            deleteAnnotation()
                        } label: {
                            Image(systemName: "trash")
                        }
                    }

                    Button("Done") {
                        commitText()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(textContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            .frame(width: 300)
            .shadow(color: .black.opacity(0.3), radius: 12, y: 4)
            .position(adjustedPosition())
        }
        .onAppear { loadAnnotation() }
    }

    // MARK: - Position

    private func adjustedPosition() -> CGPoint {
        let point = viewModel.textEditorPosition
        let panelWidth: CGFloat = 300
        let panelHeight: CGFloat = 120
        let padding: CGFloat = 8

        var x = point.x
        var y = point.y - panelHeight / 2 - 40

        x = max(padding + panelWidth / 2, min(x, viewModel.canvasSize.width - padding - panelWidth / 2))
        y = max(padding + panelHeight / 2, min(y, viewModel.canvasSize.height - padding - panelHeight / 2))

        return CGPoint(x: x, y: y)
    }

    // MARK: - Load

    private func loadAnnotation() {
        guard let annotation = viewModel.editingTextAnnotation else { return }
        textContent = annotation.text
        fontSize = annotation.fontSize
        selectedColor = Color(
            red: annotation.colorRed,
            green: annotation.colorGreen,
            blue: annotation.colorBlue,
            opacity: annotation.colorAlpha
        )
    }

    // MARK: - Commit

    private func commitText() {
        let trimmed = textContent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let annotation = viewModel.editingTextAnnotation else {
            cancel()
            return
        }

        // Extract RGBA from Color
        let resolved = UIColor(selectedColor)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        resolved.getRed(&r, green: &g, blue: &b, alpha: &a)

        annotation.text = trimmed
        annotation.fontSize = fontSize
        annotation.colorRed = Double(r)
        annotation.colorGreen = Double(g)
        annotation.colorBlue = Double(b)
        annotation.colorAlpha = Double(a)

        // Remember color/size for next annotation
        viewModel.newTextColorRed = Double(r)
        viewModel.newTextColorGreen = Double(g)
        viewModel.newTextColorBlue = Double(b)
        viewModel.newTextColorAlpha = Double(a)
        viewModel.newTextFontSize = fontSize

        if viewModel.isNewTextAnnotation {
            guard let layer = viewModel.activeLayer else {
                cancel()
                return
            }
            annotation.layer = layer
            layer.textAnnotations.append(annotation)
            modelContext.insert(annotation)
        }

        dismiss()
    }

    // MARK: - Delete

    private func deleteAnnotation() {
        guard let annotation = viewModel.editingTextAnnotation,
              !viewModel.isNewTextAnnotation else {
            cancel()
            return
        }
        modelContext.delete(annotation)
        dismiss()
    }

    // MARK: - Cancel / Dismiss

    private func cancel() {
        dismiss()
    }

    private func dismiss() {
        viewModel.editingTextAnnotation = nil
        viewModel.isShowingTextEditor = false
        viewModel.isNewTextAnnotation = false
    }
}
