import SwiftUI
import SwiftData

struct CanvasView: View {
    @Bindable var viewModel: MapEditorViewModel
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        GeometryReader { geometry in
            let cellSize = CGFloat(viewModel.project.gridCellSize)

            Canvas { context, size in
                let range = viewModel.visibleGridRange(canvasSize: size, cellSize: cellSize)

                // Draw placed tiles (layers bottom to top)
                let sortedLayers = viewModel.project.layers.sorted { $0.sortOrder < $1.sortOrder }
                for layer in sortedLayers {
                    guard layer.isVisible else { continue }

                    context.opacity = layer.opacity
                    var drawnTileIDs = Set<UUID>()
                    for tile in layer.placedTiles {
                        guard !drawnTileIDs.contains(tile.id) else { continue }

                        let tw = tile.asset?.gridWidth ?? 1
                        let th = tile.asset?.gridHeight ?? 1

                        let tileMaxX = tile.gridX + tw - 1
                        let tileMaxY = tile.gridY + th - 1
                        guard tileMaxX >= range.minX && tile.gridX <= range.maxX &&
                              tileMaxY >= range.minY && tile.gridY <= range.maxY else { continue }

                        drawnTileIDs.insert(tile.id)

                        let canvasRect = viewModel.gridToCanvas(
                            position: GridPosition(x: tile.gridX, y: tile.gridY),
                            cellSize: cellSize,
                            gridWidth: tw,
                            gridHeight: th
                        )
                        let screenRect = canvasToScreen(canvasRect)

                        if let asset = tile.asset,
                           let uiImage = ImageCache.shared.image(for: asset) {
                            let resolvedImage = context.resolve(Image(uiImage: uiImage))
                            context.draw(resolvedImage, in: screenRect)
                        } else {
                            context.fill(Path(screenRect), with: .color(.brown.opacity(0.3)))
                        }
                    }
                    context.opacity = 1.0
                }

                // Draw selection highlight
                if let selected = viewModel.selectedTile {
                    let sw = selected.asset?.gridWidth ?? 1
                    let sh = selected.asset?.gridHeight ?? 1

                    if viewModel.isDraggingSelection, let dragPos = viewModel.dragGridPosition {
                        let ghostRect = viewModel.gridToCanvas(
                            position: dragPos, cellSize: cellSize,
                            gridWidth: sw, gridHeight: sh
                        )
                        let ghostScreen = canvasToScreen(ghostRect)
                        context.opacity = 0.4
                        if let asset = selected.asset,
                           let uiImage = ImageCache.shared.image(for: asset) {
                            context.draw(context.resolve(Image(uiImage: uiImage)), in: ghostScreen)
                        }
                        context.opacity = 1.0
                        context.stroke(Path(ghostScreen), with: .color(.blue), lineWidth: 2.0)
                    }

                    let selRect = viewModel.gridToCanvas(
                        position: GridPosition(x: selected.gridX, y: selected.gridY),
                        cellSize: cellSize,
                        gridWidth: sw, gridHeight: sh
                    )
                    let selScreen = canvasToScreen(selRect)
                    context.stroke(Path(selScreen), with: .color(.blue), lineWidth: 2.5)
                    context.fill(Path(selScreen), with: .color(.blue.opacity(0.15)))
                }

                // Draw grid lines
                if viewModel.project.showGridLines {
                    drawGridLines(context: &context, size: size, range: range, cellSize: cellSize)
                }

                // Draw coordinate labels
                if viewModel.project.showCoordinateLabels {
                    drawCoordinateLabels(context: &context, size: size, range: range, cellSize: cellSize)
                }
            }
            .overlay {
                CanvasGestureOverlay(
                    viewModel: viewModel,
                    cellSize: cellSize,
                    onSingleTap: { point in handleSingleTap(at: point, cellSize: cellSize) },
                    onDoubleTap: { point in handleDoubleTap(at: point, cellSize: cellSize) },
                    onLongPress: { point in handleLongPress(at: point, cellSize: cellSize) },
                    onTileDragEnded: { handleTileDragEnd(cellSize: cellSize) }
                )
            }
            .dropDestination(for: String.self) { items, location in
                handleDrop(items: items, location: location, cellSize: cellSize)
            }
            .clipped()
            .onAppear {
                viewModel.canvasSize = geometry.size
            }
            .onChange(of: geometry.size) { _, newSize in
                viewModel.canvasSize = newSize
            }
        }
        .overlay {
            if viewModel.showContextMenu, viewModel.contextMenuTile != nil {
                // Dismiss backdrop
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .onTapGesture {
                        viewModel.dismissContextMenu()
                    }

                // Floating context menu near the touch point
                VStack(spacing: 0) {
                    Button {
                        duplicateContextMenuTile()
                    } label: {
                        Label("Duplicate", systemImage: "plus.square.on.square")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                    }
                    .tint(.primary)

                    Divider()

                    Button(role: .destructive) {
                        removeContextMenuTile()
                    } label: {
                        Label("Remove", systemImage: "trash")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                    }
                }
                .frame(width: 200)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.3), radius: 12, y: 4)
                .position(adjustedMenuPosition())
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
                .animation(.easeOut(duration: 0.15), value: viewModel.showContextMenu)
            }
        }
    }

    // MARK: - Tap Handling

    private func handleSingleTap(at point: CGPoint, cellSize: CGFloat) {
        let pos = viewModel.screenToGrid(point: point, cellSize: cellSize)
        guard let asset = viewModel.traySelectedAsset,
              let layer = viewModel.activeLayer,
              !layer.isLocked,
              viewModel.tile(at: pos, on: layer) == nil else { return }
        let service = TilePlacementService(modelContext: modelContext, viewModel: viewModel)
        service.placeTile(at: pos, asset: asset, layer: layer)
    }

    private func handleDoubleTap(at point: CGPoint, cellSize: CGFloat) {
        let pos = viewModel.screenToGrid(point: point, cellSize: cellSize)
        guard let layer = viewModel.activeLayer else { return }
        if let tile = viewModel.tile(at: pos, on: layer) {
            if viewModel.selectedTile?.id == tile.id {
                viewModel.clearSelection()
            } else {
                viewModel.selectedTile = tile
            }
        } else {
            viewModel.clearSelection()
        }
    }

    private func handleLongPress(at point: CGPoint, cellSize: CGFloat) {
        guard let layer = viewModel.activeLayer else { return }
        let pos = viewModel.screenToGrid(point: point, cellSize: cellSize)
        if let tile = viewModel.tile(at: pos, on: layer) {
            viewModel.contextMenuTile = tile
            viewModel.contextMenuPosition = point
            viewModel.showContextMenu = true
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }

    private func handleTileDragEnd(cellSize: CGFloat) {
        guard let tile = viewModel.selectedTile,
              let layer = viewModel.activeLayer,
              let dragPos = viewModel.dragGridPosition else { return }
        let service = TilePlacementService(modelContext: modelContext, viewModel: viewModel)
        service.moveTile(tile, to: dragPos, layer: layer)
    }

    // MARK: - Drop Handling

    private func handleDrop(items: [String], location: CGPoint, cellSize: CGFloat) -> Bool {
        guard let assetIDString = items.first,
              let assetID = UUID(uuidString: assetIDString),
              let layer = viewModel.activeLayer,
              !layer.isLocked else { return false }

        guard let asset = viewModel.project.assets.first(where: { $0.id == assetID }) else { return false }

        let position = viewModel.screenToGrid(point: location, cellSize: cellSize)
        let service = TilePlacementService(modelContext: modelContext, viewModel: viewModel)
        service.placeTile(at: position, asset: asset, layer: layer)
        return true
    }

    // MARK: - Context Menu Actions

    private func duplicateContextMenuTile() {
        guard let tile = viewModel.contextMenuTile,
              let layer = viewModel.activeLayer else {
            viewModel.dismissContextMenu()
            return
        }
        let service = TilePlacementService(modelContext: modelContext, viewModel: viewModel)
        service.duplicateTile(tile, on: layer)
        viewModel.dismissContextMenu()
    }

    private func removeContextMenuTile() {
        guard let tile = viewModel.contextMenuTile,
              let layer = viewModel.activeLayer else {
            viewModel.dismissContextMenu()
            return
        }
        let position = GridPosition(x: tile.gridX, y: tile.gridY)
        let service = TilePlacementService(modelContext: modelContext, viewModel: viewModel)
        service.eraseTile(at: position, layer: layer)
        if viewModel.selectedTile?.id == tile.id {
            viewModel.selectedTile = nil
        }
        viewModel.dismissContextMenu()
    }

    // MARK: - Context Menu Positioning

    private func adjustedMenuPosition() -> CGPoint {
        let point = viewModel.contextMenuPosition
        let menuWidth: CGFloat = 200
        let menuHeight: CGFloat = 100
        let padding: CGFloat = 8

        // Position above the finger
        var x = point.x
        var y = point.y - menuHeight / 2 - 30

        // Clamp to canvas bounds
        x = max(padding + menuWidth / 2, min(x, viewModel.canvasSize.width - padding - menuWidth / 2))
        y = max(padding + menuHeight / 2, min(y, viewModel.canvasSize.height - padding - menuHeight / 2))

        return CGPoint(x: x, y: y)
    }

    // MARK: - Canvas-to-Screen Transform

    private func canvasToScreen(_ rect: CGRect) -> CGRect {
        CGRect(
            x: rect.origin.x * viewModel.zoomScale + viewModel.panOffset.width,
            y: rect.origin.y * viewModel.zoomScale + viewModel.panOffset.height,
            width: rect.width * viewModel.zoomScale,
            height: rect.height * viewModel.zoomScale
        )
    }

    // MARK: - Grid Lines

    private func drawGridLines(
        context: inout GraphicsContext,
        size: CGSize,
        range: (minX: Int, maxX: Int, minY: Int, maxY: Int),
        cellSize: CGFloat
    ) {
        let lineColor = Color.white.opacity(0.15)

        for col in range.minX...range.maxX {
            let screenX = CGFloat(col) * cellSize * viewModel.zoomScale + viewModel.panOffset.width
            guard screenX >= -1 && screenX <= size.width + 1 else { continue }

            var path = Path()
            path.move(to: CGPoint(x: screenX, y: 0))
            path.addLine(to: CGPoint(x: screenX, y: size.height))
            context.stroke(path, with: .color(lineColor), lineWidth: 0.5)
        }

        for row in range.minY...range.maxY {
            let screenY = CGFloat(row) * cellSize * viewModel.zoomScale + viewModel.panOffset.height
            guard screenY >= -1 && screenY <= size.height + 1 else { continue }

            var path = Path()
            path.move(to: CGPoint(x: 0, y: screenY))
            path.addLine(to: CGPoint(x: size.width, y: screenY))
            context.stroke(path, with: .color(lineColor), lineWidth: 0.5)
        }

        // Origin crosshair
        let originX = viewModel.panOffset.width
        let originY = viewModel.panOffset.height

        if originX >= 0 && originX <= size.width {
            var path = Path()
            path.move(to: CGPoint(x: originX, y: 0))
            path.addLine(to: CGPoint(x: originX, y: size.height))
            context.stroke(path, with: .color(.white.opacity(0.4)), lineWidth: 1.5)
        }
        if originY >= 0 && originY <= size.height {
            var path = Path()
            path.move(to: CGPoint(x: 0, y: originY))
            path.addLine(to: CGPoint(x: size.width, y: originY))
            context.stroke(path, with: .color(.white.opacity(0.4)), lineWidth: 1.5)
        }
    }

    // MARK: - Coordinate Labels

    private func drawCoordinateLabels(
        context: inout GraphicsContext,
        size: CGSize,
        range: (minX: Int, maxX: Int, minY: Int, maxY: Int),
        cellSize: CGFloat
    ) {
        let scaledCell = cellSize * viewModel.zoomScale
        guard scaledCell > 20 else { return }

        let fontSize: CGFloat = min(10, scaledCell * 0.2)

        for col in range.minX...range.maxX {
            let screenX = CGFloat(col) * cellSize * viewModel.zoomScale + viewModel.panOffset.width
            guard screenX >= 0 && screenX + scaledCell <= size.width + scaledCell else { continue }

            let text = Text(CoordinateFormatter.columnLabel(col))
                .font(.system(size: fontSize, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.5))
            context.draw(context.resolve(text), at: CGPoint(x: screenX + scaledCell / 2, y: 10), anchor: .center)
        }

        for row in range.minY...range.maxY {
            let screenY = CGFloat(row) * cellSize * viewModel.zoomScale + viewModel.panOffset.height
            guard screenY >= 0 && screenY + scaledCell <= size.height + scaledCell else { continue }

            let text = Text(CoordinateFormatter.rowLabel(row))
                .font(.system(size: fontSize, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.5))
            context.draw(context.resolve(text), at: CGPoint(x: 14, y: screenY + scaledCell / 2), anchor: .center)
        }
    }
}
