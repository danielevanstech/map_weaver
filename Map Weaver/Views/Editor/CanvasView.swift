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

                // Draw background image via background layer
                if let bgLayer = viewModel.project.backgroundLayer,
                   bgLayer.isVisible,
                   let bgImage = viewModel.backgroundImage {
                    drawBackground(context: &context, size: size, bgImage: bgImage, opacity: bgLayer.opacity)
                }

                // Draw content layers (bottom to top, excluding background and grid)
                let sortedLayers = viewModel.project.layers
                    .filter { $0.layerType != .background && $0.layerType != .grid }
                    .sorted { $0.sortOrder < $1.sortOrder }

                // Draw tile layers first (below grid lines)
                for layer in sortedLayers where layer.layerType == .tile {
                    guard layer.isVisible else { continue }
                    context.opacity = layer.opacity
                    drawTiles(layer: layer, context: &context, range: range, cellSize: cellSize)
                    context.opacity = 1.0
                }

                // Draw grid lines above tiles but below drawing/text
                if let gridLayer = viewModel.project.gridLayer, gridLayer.isVisible {
                    context.opacity = gridLayer.opacity
                    drawGridLines(context: &context, size: size, range: range, cellSize: cellSize, gridLayer: gridLayer)
                    context.opacity = 1.0
                }

                // Draw drawing and text layers (above grid lines)
                for layer in sortedLayers where layer.layerType == .drawing || layer.layerType == .text {
                    guard layer.isVisible else { continue }
                    context.opacity = layer.opacity

                    switch layer.layerType {
                    case .text:
                        drawTextAnnotations(layer: layer, context: &context)
                    case .drawing:
                        drawStrokes(layer: layer, context: &context)
                    default:
                        break
                    }

                    context.opacity = 1.0
                }

                // Draw selection highlight — tiles
                if let selected = viewModel.selectedTile {
                    let sw = selected.asset?.gridWidth ?? 1
                    let sh = selected.asset?.gridHeight ?? 1

                    let selRect = viewModel.gridToCanvas(
                        position: GridPosition(x: selected.gridX, y: selected.gridY),
                        cellSize: cellSize,
                        gridWidth: sw, gridHeight: sh
                    )
                    var selScreen = canvasToScreen(selRect)

                    // Follow tile during drag
                    if viewModel.isDraggingSelection {
                        let offset = viewModel.dragCanvasOffset
                        selScreen.origin.x += offset.width * viewModel.zoomScale
                        selScreen.origin.y += offset.height * viewModel.zoomScale
                    }

                    context.stroke(Path(selScreen), with: .color(.blue), lineWidth: 2.5)
                    context.fill(Path(selScreen), with: .color(.blue.opacity(0.15)))
                }

                // Draw selection highlight — text annotation
                if let selected = viewModel.selectedTextAnnotation {
                    let offset = viewModel.isDraggingSelection ? viewModel.dragCanvasOffset : .zero
                    let cx = CGFloat(selected.canvasX) + offset.width
                    let cy = CGFloat(selected.canvasY) + offset.height
                    let screenX = cx * viewModel.zoomScale + viewModel.panOffset.width
                    let screenY = cy * viewModel.zoomScale + viewModel.panOffset.height
                    let fontSize = selected.fontSize * viewModel.zoomScale
                    // Approximate text bounds
                    let textWidth = max(fontSize * CGFloat(selected.text.count) * 0.6, 30)
                    let textHeight = max(fontSize * 1.3, 20)
                    let selRect = CGRect(x: screenX - 4, y: screenY - 4, width: textWidth + 8, height: textHeight + 8)
                    context.stroke(Path(selRect), with: .color(.blue), lineWidth: 2.5)
                    context.fill(Path(selRect), with: .color(.blue.opacity(0.15)))
                }

                // Draw selection highlight — drawing stroke
                if let selected = viewModel.selectedDrawingStroke {
                    let offset = viewModel.isDraggingSelection ? viewModel.dragCanvasOffset : .zero
                    let points = selected.points
                    if !points.isEmpty {
                        var minX = CGFloat.greatestFiniteMagnitude
                        var minY = CGFloat.greatestFiniteMagnitude
                        var maxX = -CGFloat.greatestFiniteMagnitude
                        var maxY = -CGFloat.greatestFiniteMagnitude
                        for pt in points {
                            let sx = (CGFloat(pt.x) + offset.width) * viewModel.zoomScale + viewModel.panOffset.width
                            let sy = (CGFloat(pt.y) + offset.height) * viewModel.zoomScale + viewModel.panOffset.height
                            minX = min(minX, sx); minY = min(minY, sy)
                            maxX = max(maxX, sx); maxY = max(maxY, sy)
                        }
                        let pad: CGFloat = 6
                        let selRect = CGRect(x: minX - pad, y: minY - pad, width: maxX - minX + pad * 2, height: maxY - minY + pad * 2)
                        context.stroke(Path(selRect), with: .color(.blue), lineWidth: 2.5)
                        context.fill(Path(selRect), with: .color(.blue.opacity(0.15)))
                    }
                }

                // Draw coordinate labels
                if let gridLayer = viewModel.project.gridLayer,
                   gridLayer.isVisible,
                   gridLayer.gridShowCoordinateLabels {
                    drawCoordinateLabels(context: &context, size: size, range: range, cellSize: cellSize, gridLayer: gridLayer)
                }
            }
            .overlay {
                CanvasGestureOverlay(
                    viewModel: viewModel,
                    cellSize: cellSize,
                    onSingleTap: { point in handleSingleTap(at: point, cellSize: cellSize) },
                    onLongPress: { point in handleLongPress(at: point, cellSize: cellSize) },
                    onTileDragEnded: { handleTileDragEnd(cellSize: cellSize) },
                    onStrokeCompleted: { commitDrawingStroke() },
                    onTextDragEnded: { handleTextDragEnd() },
                    onStrokeDragEnded: { handleStrokeDragEnd() }
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
            if viewModel.showContextMenu {
                // Dismiss backdrop
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .onTapGesture {
                        viewModel.dismissContextMenu()
                    }

                // Floating context menu near the touch point
                VStack(spacing: 0) {
                    // Tile context menu
                    if viewModel.contextMenuTile != nil {
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

                    // Text annotation context menu
                    if viewModel.contextMenuTextAnnotation != nil {
                        Button {
                            editContextMenuTextAnnotation()
                        } label: {
                            Label("Edit", systemImage: "pencil")
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                        }
                        .tint(.primary)

                        Divider()

                        Button {
                            duplicateContextMenuTextAnnotation()
                        } label: {
                            Label("Duplicate", systemImage: "plus.square.on.square")
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                        }
                        .tint(.primary)

                        Divider()

                        Button(role: .destructive) {
                            removeContextMenuTextAnnotation()
                        } label: {
                            Label("Remove", systemImage: "trash")
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                        }
                    }

                    // Drawing stroke context menu
                    if viewModel.contextMenuDrawingStroke != nil {
                        Button {
                            editContextMenuDrawingStroke()
                        } label: {
                            Label("Edit Color", systemImage: "paintbrush")
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                        }
                        .tint(.primary)

                        Divider()

                        Button {
                            duplicateContextMenuDrawingStroke()
                        } label: {
                            Label("Duplicate", systemImage: "plus.square.on.square")
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                        }
                        .tint(.primary)

                        Divider()

                        Button(role: .destructive) {
                            removeContextMenuDrawingStroke()
                        } label: {
                            Label("Remove", systemImage: "trash")
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                        }
                    }
                }
                .frame(width: 200)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.3), radius: 12, y: 4)
                .position(adjustedMenuPosition())
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
                .animation(.easeOut(duration: 0.15), value: viewModel.showContextMenu)
            }

            // Text editor overlay
            if viewModel.isShowingTextEditor {
                TextEditorOverlay(viewModel: viewModel)
            }

            // Stroke color editor overlay
            if viewModel.isShowingStrokeEditor, let stroke = viewModel.editingDrawingStroke {
                StrokeEditorOverlay(stroke: stroke) {
                    viewModel.editingDrawingStroke = nil
                    viewModel.isShowingStrokeEditor = false
                }
            }
        }
    }

    // MARK: - Tap Handling

    private func handleSingleTap(at point: CGPoint, cellSize: CGFloat) {
        guard let layer = viewModel.activeLayer, !layer.isLocked else { return }

        // Capture current selection IDs before clearing
        let previousTileID = viewModel.selectedTile?.id
        let previousTextID = viewModel.selectedTextAnnotation?.id
        let previousStrokeID = viewModel.selectedDrawingStroke?.id
        viewModel.clearSelection()

        switch layer.layerType {
        case .tile:
            let pos = viewModel.screenToGrid(point: point, cellSize: cellSize)
            if let tile = viewModel.tile(at: pos, on: layer) {
                // Re-select only if it's a different tile (tap same = deselect)
                if tile.id != previousTileID {
                    viewModel.selectedTile = tile
                }
            } else if let asset = viewModel.traySelectedAsset {
                // Place tile on empty space if an asset is selected
                let service = TilePlacementService(modelContext: modelContext, viewModel: viewModel)
                service.placeTile(at: pos, asset: asset, layer: layer)
            }

        case .text:
            if let annotation = viewModel.textAnnotation(near: point),
               annotation.id != previousTextID {
                viewModel.selectedTextAnnotation = annotation
            }

        case .drawing:
            if !viewModel.isDrawingModeActive,
               let stroke = viewModel.drawingStroke(near: point),
               stroke.id != previousStrokeID {
                viewModel.selectedDrawingStroke = stroke
            }

        case .background, .grid:
            break
        }
    }

    private func handleLongPress(at point: CGPoint, cellSize: CGFloat) {
        guard let layer = viewModel.activeLayer else { return }

        switch layer.layerType {
        case .tile:
            let pos = viewModel.screenToGrid(point: point, cellSize: cellSize)
            if let tile = viewModel.tile(at: pos, on: layer) {
                viewModel.contextMenuTile = tile
                viewModel.contextMenuPosition = point
                viewModel.showContextMenu = true
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
        case .text:
            if let annotation = viewModel.textAnnotation(near: point) {
                viewModel.contextMenuTextAnnotation = annotation
                viewModel.contextMenuPosition = point
                viewModel.showContextMenu = true
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
        case .drawing:
            if let stroke = viewModel.drawingStroke(near: point) {
                viewModel.contextMenuDrawingStroke = stroke
                viewModel.contextMenuPosition = point
                viewModel.showContextMenu = true
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
        case .background, .grid:
            break
        }
    }

    private func handleTileDragEnd(cellSize: CGFloat) {
        guard let tile = viewModel.selectedTile,
              let layer = viewModel.activeLayer else { return }
        let offset = viewModel.dragCanvasOffset
        guard offset != .zero else {
            viewModel.dragCanvasOffset = .zero
            return
        }
        // Convert canvas offset to grid offset and snap
        let newCanvasX = CGFloat(tile.gridX) * cellSize + offset.width
        let newCanvasY = CGFloat(tile.gridY) * cellSize + offset.height
        let newGridX = Int(round(newCanvasX / cellSize))
        let newGridY = Int(round(newCanvasY / cellSize))
        let newPos = GridPosition(x: newGridX, y: newGridY)
        let service = TilePlacementService(modelContext: modelContext, viewModel: viewModel)
        service.moveTile(tile, to: newPos, layer: layer)
        viewModel.dragCanvasOffset = .zero
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

    // MARK: - Text/Stroke Drag End

    private func handleTextDragEnd() {
        guard let annotation = viewModel.selectedTextAnnotation else { return }
        let offset = viewModel.dragCanvasOffset
        annotation.canvasX += Double(offset.width)
        annotation.canvasY += Double(offset.height)
        viewModel.isDraggingSelection = false
        viewModel.dragCanvasOffset = .zero
    }

    private func handleStrokeDragEnd() {
        guard let stroke = viewModel.selectedDrawingStroke else { return }
        let offset = viewModel.dragCanvasOffset
        // Offset all points in the stroke
        var movedPoints = stroke.points
        for i in movedPoints.indices {
            movedPoints[i] = StrokePoint(
                x: movedPoints[i].x + Double(offset.width),
                y: movedPoints[i].y + Double(offset.height),
                pressure: movedPoints[i].pressure
            )
        }
        stroke.points = movedPoints
        viewModel.isDraggingSelection = false
        viewModel.dragCanvasOffset = .zero
    }

    // MARK: - Drawing Stroke Commit

    private func commitDrawingStroke() {
        guard let layer = viewModel.activeLayer,
              layer.layerType == .drawing,
              viewModel.activeStrokePoints.count >= 2 else { return }

        let stroke = DrawingStroke(
            points: viewModel.activeStrokePoints,
            lineWidth: viewModel.newStrokeLineWidth
        )
        stroke.colorRed = viewModel.newStrokeColorRed
        stroke.colorGreen = viewModel.newStrokeColorGreen
        stroke.colorBlue = viewModel.newStrokeColorBlue
        stroke.colorAlpha = viewModel.newStrokeColorAlpha
        stroke.layer = layer
        layer.drawingStrokes.append(stroke)
        modelContext.insert(stroke)
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

    // MARK: - Text Annotation Context Menu Actions

    private func editContextMenuTextAnnotation() {
        guard let annotation = viewModel.contextMenuTextAnnotation else {
            viewModel.dismissContextMenu()
            return
        }
        viewModel.editingTextAnnotation = annotation
        viewModel.isNewTextAnnotation = false
        viewModel.textEditorPosition = viewModel.contextMenuPosition
        viewModel.isShowingTextEditor = true
        viewModel.dismissContextMenu()
    }

    private func duplicateContextMenuTextAnnotation() {
        guard let annotation = viewModel.contextMenuTextAnnotation,
              let layer = viewModel.activeLayer else {
            viewModel.dismissContextMenu()
            return
        }
        let duplicate = TextAnnotation(
            canvasX: annotation.canvasX + 20,
            canvasY: annotation.canvasY + 20,
            text: annotation.text,
            fontSize: annotation.fontSize
        )
        duplicate.colorRed = annotation.colorRed
        duplicate.colorGreen = annotation.colorGreen
        duplicate.colorBlue = annotation.colorBlue
        duplicate.colorAlpha = annotation.colorAlpha
        duplicate.layer = layer
        layer.textAnnotations.append(duplicate)
        modelContext.insert(duplicate)
        viewModel.dismissContextMenu()
    }

    private func removeContextMenuTextAnnotation() {
        guard let annotation = viewModel.contextMenuTextAnnotation else {
            viewModel.dismissContextMenu()
            return
        }
        if viewModel.selectedTextAnnotation?.id == annotation.id {
            viewModel.clearSelection()
        }
        modelContext.delete(annotation)
        viewModel.dismissContextMenu()
    }

    // MARK: - Drawing Stroke Context Menu Actions

    private func editContextMenuDrawingStroke() {
        guard let stroke = viewModel.contextMenuDrawingStroke else {
            viewModel.dismissContextMenu()
            return
        }
        viewModel.editingDrawingStroke = stroke
        viewModel.isShowingStrokeEditor = true
        viewModel.dismissContextMenu()
    }

    private func duplicateContextMenuDrawingStroke() {
        guard let stroke = viewModel.contextMenuDrawingStroke,
              let layer = viewModel.activeLayer else {
            viewModel.dismissContextMenu()
            return
        }
        // Offset duplicated stroke slightly
        let offsetPoints = stroke.points.map {
            StrokePoint(x: $0.x + 20, y: $0.y + 20, pressure: $0.pressure)
        }
        let duplicate = DrawingStroke(points: offsetPoints, lineWidth: stroke.lineWidth)
        duplicate.colorRed = stroke.colorRed
        duplicate.colorGreen = stroke.colorGreen
        duplicate.colorBlue = stroke.colorBlue
        duplicate.colorAlpha = stroke.colorAlpha
        duplicate.layer = layer
        layer.drawingStrokes.append(duplicate)
        modelContext.insert(duplicate)
        viewModel.dismissContextMenu()
    }

    private func removeContextMenuDrawingStroke() {
        guard let stroke = viewModel.contextMenuDrawingStroke else {
            viewModel.dismissContextMenu()
            return
        }
        if viewModel.selectedDrawingStroke?.id == stroke.id {
            viewModel.clearSelection()
        }
        modelContext.delete(stroke)
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

    // MARK: - Tile Rendering

    private func drawTiles(
        layer: MapLayer,
        context: inout GraphicsContext,
        range: (minX: Int, maxX: Int, minY: Int, maxY: Int),
        cellSize: CGFloat
    ) {
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
            var screenRect = canvasToScreen(canvasRect)

            // Apply drag offset if this tile is being dragged
            if viewModel.selectedTile?.id == tile.id && viewModel.isDraggingSelection {
                let offset = viewModel.dragCanvasOffset
                screenRect.origin.x += offset.width * viewModel.zoomScale
                screenRect.origin.y += offset.height * viewModel.zoomScale
            }

            if let asset = tile.asset,
               let uiImage = ImageCache.shared.image(for: asset) {
                let resolvedImage = context.resolve(Image(uiImage: uiImage))
                context.draw(resolvedImage, in: screenRect)
            } else {
                context.fill(Path(screenRect), with: .color(.brown.opacity(0.3)))
            }
        }
    }

    // MARK: - Text Annotation Rendering

    private func drawTextAnnotations(layer: MapLayer, context: inout GraphicsContext) {
        for annotation in layer.textAnnotations {
            // Apply drag offset if this annotation is being dragged
            let dragOffset = (viewModel.selectedTextAnnotation?.id == annotation.id && viewModel.isDraggingSelection)
                ? viewModel.dragCanvasOffset : .zero
            let screenX = (CGFloat(annotation.canvasX) + dragOffset.width) * viewModel.zoomScale + viewModel.panOffset.width
            let screenY = (CGFloat(annotation.canvasY) + dragOffset.height) * viewModel.zoomScale + viewModel.panOffset.height
            let scaledFontSize = CGFloat(annotation.fontSize) * viewModel.zoomScale
            guard scaledFontSize > 2 else { continue }

            let color = Color(
                red: annotation.colorRed,
                green: annotation.colorGreen,
                blue: annotation.colorBlue,
                opacity: annotation.colorAlpha
            )
            let text = Text(annotation.text)
                .font(.system(size: scaledFontSize))
                .foregroundStyle(color)
            context.draw(
                context.resolve(text),
                at: CGPoint(x: screenX, y: screenY),
                anchor: .topLeading
            )
        }
    }

    // MARK: - Drawing Stroke Rendering

    private func drawStrokes(layer: MapLayer, context: inout GraphicsContext) {
        for stroke in layer.drawingStrokes {
            let color = Color(
                red: stroke.colorRed,
                green: stroke.colorGreen,
                blue: stroke.colorBlue,
                opacity: stroke.colorAlpha
            )
            // Apply drag offset if this stroke is being dragged
            let offset = (viewModel.selectedDrawingStroke?.id == stroke.id && viewModel.isDraggingSelection)
                ? viewModel.dragCanvasOffset : .zero
            drawStrokePath(stroke.points, color: color, lineWidth: stroke.lineWidth, canvasOffset: offset, context: &context)
        }

        // Draw in-progress stroke for the active drawing layer
        if layer.id == viewModel.activeLayer?.id, !viewModel.activeStrokePoints.isEmpty {
            let color = Color(
                red: viewModel.newStrokeColorRed,
                green: viewModel.newStrokeColorGreen,
                blue: viewModel.newStrokeColorBlue,
                opacity: viewModel.newStrokeColorAlpha
            )
            drawStrokePath(viewModel.activeStrokePoints, color: color, lineWidth: viewModel.newStrokeLineWidth, canvasOffset: .zero, context: &context)
        }
    }

    private func drawStrokePath(
        _ points: [StrokePoint],
        color: Color,
        lineWidth: Double,
        canvasOffset: CGSize,
        context: inout GraphicsContext
    ) {
        guard points.count >= 2 else { return }

        var path = Path()
        let first = points[0]
        let screenFirst = CGPoint(
            x: (first.x + canvasOffset.width) * viewModel.zoomScale + Double(viewModel.panOffset.width),
            y: (first.y + canvasOffset.height) * viewModel.zoomScale + Double(viewModel.panOffset.height)
        )
        path.move(to: screenFirst)

        for i in 1..<points.count {
            let p = points[i]
            let screenP = CGPoint(
                x: (p.x + canvasOffset.width) * viewModel.zoomScale + Double(viewModel.panOffset.width),
                y: (p.y + canvasOffset.height) * viewModel.zoomScale + Double(viewModel.panOffset.height)
            )
            path.addLine(to: screenP)
        }

        let scaledLineWidth = lineWidth * viewModel.zoomScale
        context.stroke(path, with: .color(color), style: StrokeStyle(
            lineWidth: scaledLineWidth,
            lineCap: .round,
            lineJoin: .round
        ))
    }

    // MARK: - Background Image

    private func drawBackground(
        context: inout GraphicsContext,
        size: CGSize,
        bgImage: UIImage,
        opacity: Double
    ) {
        let imgSize = bgImage.size
        let mode = viewModel.project.backgroundDisplayMode

        let drawRect: CGRect
        switch mode {
        case .originalSize:
            drawRect = CGRect(
                x: (size.width - imgSize.width) / 2,
                y: (size.height - imgSize.height) / 2,
                width: imgSize.width,
                height: imgSize.height
            )
        case .stretchToFit:
            drawRect = CGRect(origin: .zero, size: size)
        case .aspectFit:
            let scale = min(size.width / imgSize.width, size.height / imgSize.height)
            let scaledSize = CGSize(width: imgSize.width * scale, height: imgSize.height * scale)
            drawRect = CGRect(
                x: (size.width - scaledSize.width) / 2,
                y: (size.height - scaledSize.height) / 2,
                width: scaledSize.width,
                height: scaledSize.height
            )
        case .aspectFill:
            let scale = max(size.width / imgSize.width, size.height / imgSize.height)
            let scaledSize = CGSize(width: imgSize.width * scale, height: imgSize.height * scale)
            drawRect = CGRect(
                x: (size.width - scaledSize.width) / 2,
                y: (size.height - scaledSize.height) / 2,
                width: scaledSize.width,
                height: scaledSize.height
            )
        }

        context.opacity = opacity
        context.draw(context.resolve(Image(uiImage: bgImage)), in: drawRect)
        context.opacity = 1.0
    }

    // MARK: - Grid Lines

    private func drawGridLines(
        context: inout GraphicsContext,
        size: CGSize,
        range: (minX: Int, maxX: Int, minY: Int, maxY: Int),
        cellSize: CGFloat,
        gridLayer: MapLayer
    ) {
        let lineColor = Color(
            red: gridLayer.gridColorRed,
            green: gridLayer.gridColorGreen,
            blue: gridLayer.gridColorBlue,
            opacity: gridLayer.gridColorAlpha
        )
        let originAlpha = min(gridLayer.gridColorAlpha * 2.0, 1.0)
        let originColor = Color(
            red: gridLayer.gridColorRed,
            green: gridLayer.gridColorGreen,
            blue: gridLayer.gridColorBlue,
            opacity: originAlpha
        )
        let lineWidth = gridLayer.gridLineWidth
        let showOriginLines = gridLayer.gridShowCoordinateLabels

        for col in range.minX...range.maxX {
            let screenX = CGFloat(col) * cellSize * viewModel.zoomScale + viewModel.panOffset.width
            guard screenX >= -1 && screenX <= size.width + 1 else { continue }

            var path = Path()
            path.move(to: CGPoint(x: screenX, y: 0))
            path.addLine(to: CGPoint(x: screenX, y: size.height))

            let isOrigin = col == 0 && showOriginLines
            context.stroke(path, with: .color(isOrigin ? originColor : lineColor), lineWidth: isOrigin ? lineWidth + 1.0 : lineWidth)
        }

        for row in range.minY...range.maxY {
            let screenY = CGFloat(row) * cellSize * viewModel.zoomScale + viewModel.panOffset.height
            guard screenY >= -1 && screenY <= size.height + 1 else { continue }

            var path = Path()
            path.move(to: CGPoint(x: 0, y: screenY))
            path.addLine(to: CGPoint(x: size.width, y: screenY))

            let isOrigin = row == 0 && showOriginLines
            context.stroke(path, with: .color(isOrigin ? originColor : lineColor), lineWidth: isOrigin ? lineWidth + 1.0 : lineWidth)
        }
    }

    // MARK: - Coordinate Labels

    private func drawCoordinateLabels(
        context: inout GraphicsContext,
        size: CGSize,
        range: (minX: Int, maxX: Int, minY: Int, maxY: Int),
        cellSize: CGFloat,
        gridLayer: MapLayer
    ) {
        let scaledCell = cellSize * viewModel.zoomScale
        guard scaledCell > 20 else { return }

        let fontSize: CGFloat = min(10, scaledCell * 0.2)
        let labelColor = Color(
            red: gridLayer.gridColorRed,
            green: gridLayer.gridColorGreen,
            blue: gridLayer.gridColorBlue,
            opacity: gridLayer.gridColorAlpha * 0.7
        )

        for col in range.minX...range.maxX {
            let screenX = CGFloat(col) * cellSize * viewModel.zoomScale + viewModel.panOffset.width
            guard screenX >= 0 && screenX + scaledCell <= size.width + scaledCell else { continue }

            let text = Text(CoordinateFormatter.columnLabel(col))
                .font(.system(size: fontSize, weight: .medium, design: .monospaced))
                .foregroundStyle(labelColor)
            context.draw(context.resolve(text), at: CGPoint(x: screenX + scaledCell / 2, y: 10), anchor: .center)
        }

        for row in range.minY...range.maxY {
            let screenY = CGFloat(row) * cellSize * viewModel.zoomScale + viewModel.panOffset.height
            guard screenY >= 0 && screenY + scaledCell <= size.height + scaledCell else { continue }

            let text = Text(CoordinateFormatter.rowLabel(row))
                .font(.system(size: fontSize, weight: .medium, design: .monospaced))
                .foregroundStyle(labelColor)
            context.draw(context.resolve(text), at: CGPoint(x: 14, y: screenY + scaledCell / 2), anchor: .center)
        }
    }
}
