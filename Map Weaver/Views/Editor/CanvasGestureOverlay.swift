import SwiftUI
import UIKit

/// Transparent UIKit-based gesture overlay that provides Maps/Procreate-style
/// simultaneous pinch-zoom and pan using native UIGestureRecognizers.
///
/// UIKit's gesture system properly separates the pinch center (which moves
/// when both fingers translate) from the zoom scale, allowing true
/// simultaneous zoom + pan. SwiftUI's MagnifyGesture cannot do this.
struct CanvasGestureOverlay: UIViewRepresentable {
    let viewModel: MapEditorViewModel
    let cellSize: CGFloat
    let onSingleTap: (CGPoint) -> Void
    let onLongPress: (CGPoint) -> Void
    let onTileDragEnded: () -> Void
    var onStrokeCompleted: () -> Void = {}
    var onTextDragEnded: () -> Void = {}
    var onStrokeDragEnded: () -> Void = {}

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear

        let c = context.coordinator

        // Pinch (zoom)
        let pinch = UIPinchGestureRecognizer(target: c, action: #selector(Coordinator.handlePinch))
        pinch.delegate = c
        view.addGestureRecognizer(pinch)

        // Pan (1–2 fingers)
        let pan = UIPanGestureRecognizer(target: c, action: #selector(Coordinator.handlePan))
        pan.minimumNumberOfTouches = 1
        pan.maximumNumberOfTouches = 2
        pan.delegate = c
        view.addGestureRecognizer(pan)

        // Single tap (select / place / interact — fires immediately)
        let singleTap = UITapGestureRecognizer(target: c, action: #selector(Coordinator.handleSingleTap))
        singleTap.numberOfTapsRequired = 1
        view.addGestureRecognizer(singleTap)

        // Long press (context menu)
        let longPress = UILongPressGestureRecognizer(target: c, action: #selector(Coordinator.handleLongPress))
        longPress.minimumPressDuration = 0.5
        longPress.allowableMovement = 20
        view.addGestureRecognizer(longPress)

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.parent = self
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var parent: CanvasGestureOverlay
        private var isDraggingTile = false
        private var isDraggingTextAnnotation = false
        private var isDraggingDrawingStroke = false
        private var isDrawingStroke = false

        init(parent: CanvasGestureOverlay) {
            self.parent = parent
        }

        // Allow pinch + pan and long press + pan to fire simultaneously
        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
        ) -> Bool {
            let isPinch = gestureRecognizer is UIPinchGestureRecognizer || other is UIPinchGestureRecognizer
            let isPan = gestureRecognizer is UIPanGestureRecognizer || other is UIPanGestureRecognizer
            let isLongPress = gestureRecognizer is UILongPressGestureRecognizer || other is UILongPressGestureRecognizer
            if isPinch && isPan { return true }
            if isLongPress && isPan { return true }
            return false
        }

        // MARK: - Pinch (Zoom)

        @objc func handlePinch(_ g: UIPinchGestureRecognizer) {
            let vm = parent.viewModel

            switch g.state {
            case .changed:
                guard let view = g.view else { return }
                let center = g.location(in: view)
                let oldScale = vm.zoomScale
                let newScale = min(max(oldScale * g.scale, MapEditorViewModel.minZoom), MapEditorViewModel.maxZoom)

                // Anchor zoom at the live pinch center
                let cx = (center.x - vm.panOffset.width) / oldScale
                let cy = (center.y - vm.panOffset.height) / oldScale
                vm.panOffset = CGSize(
                    width: center.x - cx * newScale,
                    height: center.y - cy * newScale
                )
                vm.zoomScale = newScale
                g.scale = 1.0 // reset for next delta

            case .ended, .cancelled:
                break

            default: break
            }
        }

        // MARK: - Pan

        @objc func handlePan(_ g: UIPanGestureRecognizer) {
            guard let view = g.view else { return }
            let vm = parent.viewModel

            switch g.state {
            case .began:
                let loc = g.location(in: view)
                isDraggingTile = false
                isDraggingTextAnnotation = false
                isDraggingDrawingStroke = false
                isDrawingStroke = false

                // Only allow item dragging with a single finger
                guard g.numberOfTouches == 1 else { break }

                // Check for tile drag first
                if let selected = vm.selectedTile, let layer = vm.activeLayer, layer.layerType == .tile {
                    let pos = vm.screenToGrid(point: loc, cellSize: parent.cellSize)
                    if vm.tile(at: pos, on: layer)?.id == selected.id {
                        isDraggingTile = true
                        vm.isDraggingSelection = true
                        let canvasX = (loc.x - vm.panOffset.width) / vm.zoomScale
                        let canvasY = (loc.y - vm.panOffset.height) / vm.zoomScale
                        vm.dragStartCanvasPoint = CGPoint(x: canvasX, y: canvasY)
                        vm.dragCanvasOffset = .zero
                        return
                    }
                }

                // Check for selected text annotation drag
                if let selected = vm.selectedTextAnnotation {
                    let screenX = CGFloat(selected.canvasX) * vm.zoomScale + vm.panOffset.width
                    let screenY = CGFloat(selected.canvasY) * vm.zoomScale + vm.panOffset.height
                    let fontSize = CGFloat(selected.fontSize) * vm.zoomScale
                    let textWidth = max(fontSize * CGFloat(selected.text.count) * 0.6, 40)
                    let textHeight = max(fontSize * 1.3, 24)
                    let pad: CGFloat = 20
                    let hitRect = CGRect(x: screenX - pad, y: screenY - pad,
                                         width: textWidth + pad * 2, height: textHeight + pad * 2)
                    if hitRect.contains(loc) {
                        isDraggingTextAnnotation = true
                        vm.isDraggingSelection = true
                        let canvasX = (loc.x - vm.panOffset.width) / vm.zoomScale
                        let canvasY = (loc.y - vm.panOffset.height) / vm.zoomScale
                        vm.dragStartCanvasPoint = CGPoint(x: canvasX, y: canvasY)
                        vm.dragCanvasOffset = .zero
                        return
                    }
                }

                // Check for selected drawing stroke drag
                if let selected = vm.selectedDrawingStroke {
                    // Check if touch is near any point of the selected stroke
                    var nearStroke = false
                    for point in selected.points {
                        let screenX = CGFloat(point.x) * vm.zoomScale + vm.panOffset.width
                        let screenY = CGFloat(point.y) * vm.zoomScale + vm.panOffset.height
                        let distance = hypot(loc.x - screenX, loc.y - screenY)
                        if distance < 40 {
                            nearStroke = true
                            break
                        }
                    }
                    if nearStroke {
                        isDraggingDrawingStroke = true
                        vm.isDraggingSelection = true
                        let canvasX = (loc.x - vm.panOffset.width) / vm.zoomScale
                        let canvasY = (loc.y - vm.panOffset.height) / vm.zoomScale
                        vm.dragStartCanvasPoint = CGPoint(x: canvasX, y: canvasY)
                        vm.dragCanvasOffset = .zero
                        return
                    }
                }

                // Check for drawing mode (single finger only)
                if vm.isDrawingLayerActive && vm.isDrawingModeActive && g.numberOfTouches == 1 {
                    isDrawingStroke = true
                    let canvasX = Double((loc.x - vm.panOffset.width) / vm.zoomScale)
                    let canvasY = Double((loc.y - vm.panOffset.height) / vm.zoomScale)
                    vm.activeStrokePoints = [StrokePoint(x: canvasX, y: canvasY, pressure: 1.0)]
                }

            case .changed:
                if isDraggingTile || isDraggingTextAnnotation || isDraggingDrawingStroke {
                    let loc = g.location(in: view)
                    let canvasX = (loc.x - vm.panOffset.width) / vm.zoomScale
                    let canvasY = (loc.y - vm.panOffset.height) / vm.zoomScale
                    vm.dragCanvasOffset = CGSize(
                        width: canvasX - vm.dragStartCanvasPoint.x,
                        height: canvasY - vm.dragStartCanvasPoint.y
                    )
                } else if isDrawingStroke {
                    let loc = g.location(in: view)
                    let canvasX = Double((loc.x - vm.panOffset.width) / vm.zoomScale)
                    let canvasY = Double((loc.y - vm.panOffset.height) / vm.zoomScale)
                    vm.activeStrokePoints.append(StrokePoint(x: canvasX, y: canvasY, pressure: 1.0))
                } else {
                    let t = g.translation(in: view)
                    vm.panOffset = CGSize(
                        width: vm.panOffset.width + t.x,
                        height: vm.panOffset.height + t.y
                    )
                    g.setTranslation(.zero, in: view) // reset for next delta
                }

            case .ended, .cancelled:
                if isDraggingTile {
                    parent.onTileDragEnded()
                    vm.isDraggingSelection = false
                    isDraggingTile = false
                } else if isDraggingTextAnnotation {
                    parent.onTextDragEnded()
                    vm.isDraggingSelection = false
                    isDraggingTextAnnotation = false
                } else if isDraggingDrawingStroke {
                    parent.onStrokeDragEnded()
                    vm.isDraggingSelection = false
                    isDraggingDrawingStroke = false
                } else if isDrawingStroke {
                    parent.onStrokeCompleted()
                    vm.activeStrokePoints = []
                    isDrawingStroke = false
                }

            default: break
            }
        }

        // MARK: - Taps

        @objc func handleSingleTap(_ g: UITapGestureRecognizer) {
            guard g.state == .ended, let view = g.view else { return }
            parent.onSingleTap(g.location(in: view))
        }

        // MARK: - Long Press

        @objc func handleLongPress(_ g: UILongPressGestureRecognizer) {
            guard g.state == .began, let view = g.view else { return }
            parent.onLongPress(g.location(in: view))
        }
    }
}
