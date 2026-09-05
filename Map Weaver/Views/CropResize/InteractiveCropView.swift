import SwiftUI

/// Full-screen interactive crop view with a draggable, resizable crop rectangle
/// that maintains the target aspect ratio (gridWidth / gridHeight).
struct InteractiveCropView: View {
    let sourceImage: UIImage
    let targetAspectRatio: CGFloat
    let onCrop: (UIImage) -> Void
    let onCancel: () -> Void

    @State private var cropRect: CGRect = .zero
    @State private var imageFrame: CGRect = .zero
    @State private var activeDrag: DragType? = nil
    @State private var dragStartCropRect: CGRect = .zero

    private let handleSize: CGFloat = 28
    private let minCropDimension: CGFloat = 40

    enum DragType {
        case move
        case topLeft, topRight, bottomLeft, bottomRight
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
                    Color.black.ignoresSafeArea()

                    // Source image
                    Image(uiImage: sourceImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(
                            GeometryReader { imgGeo in
                                Color.clear.onAppear {
                                    imageFrame = imgGeo.frame(in: .named("cropSpace"))
                                    initializeCropRect()
                                }
                                .onChange(of: imgGeo.size) {
                                    imageFrame = imgGeo.frame(in: .named("cropSpace"))
                                    initializeCropRect()
                                }
                            }
                        )

                    // Dimming overlay with crop cutout
                    if cropRect != .zero {
                        dimmingOverlay
                        cropBorder
                        cornerHandles
                    }
                }
                .coordinateSpace(name: "cropSpace")
                .gesture(dragGesture)
            }
            .navigationTitle("Crop Image")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Crop") { performCrop() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Dimming Overlay

    private var dimmingOverlay: some View {
        Canvas { context, size in
            // Fill entire area with dark overlay
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black.opacity(0.5)))
            // Clear the crop area
            context.blendMode = .destinationOut
            context.fill(Path(cropRect), with: .color(.white))
        }
        .allowsHitTesting(false)
    }

    // MARK: - Crop Border

    private var cropBorder: some View {
        Rectangle()
            .stroke(.white, lineWidth: 2)
            .frame(width: cropRect.width, height: cropRect.height)
            .position(x: cropRect.midX, y: cropRect.midY)
            .allowsHitTesting(false)
    }

    // MARK: - Corner Handles

    private var cornerHandles: some View {
        ZStack {
            cornerHandle(at: CGPoint(x: cropRect.minX, y: cropRect.minY))
            cornerHandle(at: CGPoint(x: cropRect.maxX, y: cropRect.minY))
            cornerHandle(at: CGPoint(x: cropRect.minX, y: cropRect.maxY))
            cornerHandle(at: CGPoint(x: cropRect.maxX, y: cropRect.maxY))
        }
        .allowsHitTesting(false)
    }

    private func cornerHandle(at point: CGPoint) -> some View {
        Circle()
            .fill(.white)
            .frame(width: 12, height: 12)
            .shadow(color: .black.opacity(0.4), radius: 2)
            .position(point)
    }

    // MARK: - Drag Gesture

    private var dragGesture: some Gesture {
        DragGesture(coordinateSpace: .named("cropSpace"))
            .onChanged { value in
                if activeDrag == nil {
                    activeDrag = determineDragType(at: value.startLocation)
                    dragStartCropRect = cropRect
                }

                guard let dragType = activeDrag else { return }

                switch dragType {
                case .move:
                    handleMove(translation: value.translation)
                case .topLeft:
                    handleCornerResize(corner: .topLeft, location: value.location)
                case .topRight:
                    handleCornerResize(corner: .topRight, location: value.location)
                case .bottomLeft:
                    handleCornerResize(corner: .bottomLeft, location: value.location)
                case .bottomRight:
                    handleCornerResize(corner: .bottomRight, location: value.location)
                }
            }
            .onEnded { _ in
                activeDrag = nil
            }
    }

    private func determineDragType(at point: CGPoint) -> DragType? {
        let threshold: CGFloat = handleSize

        // Check corners first
        if distance(point, CGPoint(x: cropRect.minX, y: cropRect.minY)) < threshold { return .topLeft }
        if distance(point, CGPoint(x: cropRect.maxX, y: cropRect.minY)) < threshold { return .topRight }
        if distance(point, CGPoint(x: cropRect.minX, y: cropRect.maxY)) < threshold { return .bottomLeft }
        if distance(point, CGPoint(x: cropRect.maxX, y: cropRect.maxY)) < threshold { return .bottomRight }

        // Check if inside crop rect
        if cropRect.contains(point) { return .move }

        return nil
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }

    // MARK: - Move

    private func handleMove(translation: CGSize) {
        var newRect = dragStartCropRect.offsetBy(dx: translation.width, dy: translation.height)

        // Clamp to image bounds
        newRect.origin.x = max(imageFrame.minX, min(newRect.origin.x, imageFrame.maxX - newRect.width))
        newRect.origin.y = max(imageFrame.minY, min(newRect.origin.y, imageFrame.maxY - newRect.height))

        cropRect = newRect
    }

    // MARK: - Corner Resize

    private func handleCornerResize(corner: DragType, location: CGPoint) {
        let loc = CGPoint(
            x: max(imageFrame.minX, min(location.x, imageFrame.maxX)),
            y: max(imageFrame.minY, min(location.y, imageFrame.maxY))
        )

        var newRect = dragStartCropRect

        switch corner {
        case .bottomRight:
            let newWidth = max(minCropDimension, loc.x - dragStartCropRect.minX)
            let newHeight = newWidth / targetAspectRatio
            newRect.size = CGSize(width: newWidth, height: newHeight)

        case .bottomLeft:
            let newWidth = max(minCropDimension, dragStartCropRect.maxX - loc.x)
            let newHeight = newWidth / targetAspectRatio
            newRect.origin.x = dragStartCropRect.maxX - newWidth
            newRect.size = CGSize(width: newWidth, height: newHeight)

        case .topRight:
            let newWidth = max(minCropDimension, loc.x - dragStartCropRect.minX)
            let newHeight = newWidth / targetAspectRatio
            newRect.origin.y = dragStartCropRect.maxY - newHeight
            newRect.size = CGSize(width: newWidth, height: newHeight)

        case .topLeft:
            let newWidth = max(minCropDimension, dragStartCropRect.maxX - loc.x)
            let newHeight = newWidth / targetAspectRatio
            newRect.origin.x = dragStartCropRect.maxX - newWidth
            newRect.origin.y = dragStartCropRect.maxY - newHeight
            newRect.size = CGSize(width: newWidth, height: newHeight)

        default: break
        }

        // Clamp to image bounds
        newRect.origin.x = max(imageFrame.minX, newRect.origin.x)
        newRect.origin.y = max(imageFrame.minY, newRect.origin.y)
        if newRect.maxX > imageFrame.maxX {
            let w = imageFrame.maxX - newRect.origin.x
            newRect.size = CGSize(width: w, height: w / targetAspectRatio)
        }
        if newRect.maxY > imageFrame.maxY {
            let h = imageFrame.maxY - newRect.origin.y
            newRect.size = CGSize(width: h * targetAspectRatio, height: h)
        }

        if newRect.width >= minCropDimension && newRect.height >= minCropDimension {
            cropRect = newRect
        }
    }

    // MARK: - Initialize Crop Rect

    private func initializeCropRect() {
        guard imageFrame.width > 0, imageFrame.height > 0 else { return }

        // Largest centered rect matching target aspect ratio
        let frameAspect = imageFrame.width / imageFrame.height

        let cropWidth: CGFloat
        let cropHeight: CGFloat

        if targetAspectRatio > frameAspect {
            // Target is wider — fit to width
            cropWidth = imageFrame.width * 0.85
            cropHeight = cropWidth / targetAspectRatio
        } else {
            // Target is taller — fit to height
            cropHeight = imageFrame.height * 0.85
            cropWidth = cropHeight * targetAspectRatio
        }

        cropRect = CGRect(
            x: imageFrame.midX - cropWidth / 2,
            y: imageFrame.midY - cropHeight / 2,
            width: cropWidth,
            height: cropHeight
        )
    }

    // MARK: - Perform Crop

    private func performCrop() {
        guard imageFrame.width > 0 else { return }

        // Convert display coordinates to image coordinates
        let scaleX = sourceImage.size.width / imageFrame.width
        let scaleY = sourceImage.size.height / imageFrame.height

        let imageCropRect = CGRect(
            x: (cropRect.minX - imageFrame.minX) * scaleX,
            y: (cropRect.minY - imageFrame.minY) * scaleY,
            width: cropRect.width * scaleX,
            height: cropRect.height * scaleY
        )

        if let cropped = sourceImage.cropped(to: imageCropRect) {
            onCrop(cropped)
        }
    }
}
