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
    let onDoubleTap: (CGPoint) -> Void
    let onLongPress: (CGPoint) -> Void
    let onTileDragEnded: () -> Void

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

        // Double tap (select / deselect)
        let doubleTap = UITapGestureRecognizer(target: c, action: #selector(Coordinator.handleDoubleTap))
        doubleTap.numberOfTapsRequired = 2
        view.addGestureRecognizer(doubleTap)

        // Single tap (place tile — waits for double-tap to fail)
        let singleTap = UITapGestureRecognizer(target: c, action: #selector(Coordinator.handleSingleTap))
        singleTap.numberOfTapsRequired = 1
        singleTap.require(toFail: doubleTap)
        view.addGestureRecognizer(singleTap)

        // Long press (context menu)
        let longPress = UILongPressGestureRecognizer(target: c, action: #selector(Coordinator.handleLongPress))
        longPress.minimumPressDuration = 0.5
        longPress.allowableMovement = 10
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

        init(parent: CanvasGestureOverlay) {
            self.parent = parent
        }

        // Allow pinch + pan to fire simultaneously (Maps-style)
        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
        ) -> Bool {
            let isPinch = gestureRecognizer is UIPinchGestureRecognizer || other is UIPinchGestureRecognizer
            let isPan = gestureRecognizer is UIPanGestureRecognizer || other is UIPanGestureRecognizer
            return isPinch && isPan
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
                vm.lastPanOffset = vm.panOffset
                g.scale = 1.0 // reset for next delta

            case .ended, .cancelled:
                vm.lastZoomScale = vm.zoomScale
                vm.lastPanOffset = vm.panOffset

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
                if let selected = vm.selectedTile, let layer = vm.activeLayer {
                    let pos = vm.screenToGrid(point: loc, cellSize: parent.cellSize)
                    if vm.tile(at: pos, on: layer)?.id == selected.id {
                        isDraggingTile = true
                        vm.isDraggingSelection = true
                    }
                }

            case .changed:
                if isDraggingTile {
                    let loc = g.location(in: view)
                    let pos = vm.screenToGrid(point: loc, cellSize: parent.cellSize)
                    vm.dragGridPosition = pos
                } else {
                    let t = g.translation(in: view)
                    vm.panOffset = CGSize(
                        width: vm.panOffset.width + t.x,
                        height: vm.panOffset.height + t.y
                    )
                    vm.lastPanOffset = vm.panOffset
                    g.setTranslation(.zero, in: view) // reset for next delta
                }

            case .ended, .cancelled:
                if isDraggingTile {
                    parent.onTileDragEnded()
                    vm.isDraggingSelection = false
                    vm.dragGridPosition = nil
                    isDraggingTile = false
                } else {
                    vm.lastPanOffset = vm.panOffset
                }

            default: break
            }
        }

        // MARK: - Taps

        @objc func handleDoubleTap(_ g: UITapGestureRecognizer) {
            guard g.state == .ended, let view = g.view else { return }
            parent.onDoubleTap(g.location(in: view))
        }

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
