import SwiftUI

struct LayerRowView: View {
    @Bindable var layer: MapLayer
    let isActive: Bool
    let onSelect: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            // Top row: indicator, icon, name, info, buttons
            HStack(spacing: 10) {
                // Active indicator
                Circle()
                    .fill(isActive ? Color.blue : Color.clear)
                    .frame(width: 10, height: 10)

                // Layer type icon
                Image(systemName: layer.layerType.iconName)
                    .font(.system(size: 18))
                    .foregroundStyle(.secondary)
                    .frame(width: 24)

                // Layer name
                Text(layer.name)
                    .font(.body)
                    .fontWeight(isActive ? .semibold : .regular)
                    .lineLimit(1)

                // Item count
                switch layer.layerType {
                case .tile:
                    Text("· \(layer.placedTiles.count) tiles")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                case .text:
                    Text("· \(layer.textAnnotations.count) annotations")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                case .drawing:
                    Text("· \(layer.drawingStrokes.count) strokes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                case .background, .grid:
                    EmptyView()
                }

                Spacer(minLength: 4)

                // Visibility toggle
                Button {
                    layer.isVisible.toggle()
                } label: {
                    Image(systemName: layer.isVisible ? "eye.fill" : "eye.slash")
                        .font(.system(size: 18))
                        .foregroundStyle(layer.isVisible ? .primary : .secondary)
                        .frame(minWidth: 36, minHeight: 36)
                }
                .buttonStyle(.borderless)

                // Lock toggle
                Button {
                    layer.isLocked.toggle()
                } label: {
                    Image(systemName: layer.isLocked ? "lock.fill" : "lock.open")
                        .font(.system(size: 18))
                        .foregroundStyle(layer.isLocked ? .orange : .secondary)
                        .frame(minWidth: 36, minHeight: 36)
                }
                .buttonStyle(.borderless)
            }

            // Bottom row: opacity slider (only when visible)
            if layer.isVisible {
                HStack(spacing: 8) {
                    Spacer()
                        .frame(width: 44) // align under name

                    Text("\(Int(layer.opacity * 100))%")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 36)

                    Slider(value: $layer.opacity, in: 0.1...1.0)
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
    }
}
