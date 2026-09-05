import SwiftUI

struct LayerRowView: View {
    @Bindable var layer: MapLayer
    let isActive: Bool
    let onSelect: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Active indicator
            Circle()
                .fill(isActive ? Color.blue : Color.clear)
                .frame(width: 8, height: 8)

            // Layer name
            VStack(alignment: .leading, spacing: 2) {
                Text(layer.name)
                    .font(.subheadline)
                    .fontWeight(isActive ? .semibold : .regular)

                Text("\(layer.placedTiles.count) tiles")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Opacity control (compact)
            if layer.isVisible {
                Text("\(Int(layer.opacity * 100))%")
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 30)

                Slider(value: $layer.opacity, in: 0.1...1.0)
                    .frame(width: 60)
            }

            // Visibility toggle
            Button {
                layer.isVisible.toggle()
            } label: {
                Image(systemName: layer.isVisible ? "eye.fill" : "eye.slash")
                    .foregroundStyle(layer.isVisible ? .primary : .secondary)
            }
            .buttonStyle(.borderless)

            // Lock toggle
            Button {
                layer.isLocked.toggle()
            } label: {
                Image(systemName: layer.isLocked ? "lock.fill" : "lock.open")
                    .foregroundStyle(layer.isLocked ? .orange : .secondary)
            }
            .buttonStyle(.borderless)
        }
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
    }
}
