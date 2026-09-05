import UIKit

extension UIImage {
    /// Crops the image to the specified rect (in image-point coordinates).
    /// Uses UIKit drawing to correctly handle image orientation.
    func cropped(to rect: CGRect) -> UIImage? {
        guard rect.width > 0, rect.height > 0 else { return nil }
        let renderer = UIGraphicsImageRenderer(size: rect.size)
        return renderer.image { _ in
            draw(at: CGPoint(x: -rect.origin.x, y: -rect.origin.y))
        }
    }

    /// Resizes the image to the target size.
    func resized(to targetSize: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }

    /// Auto-fit: center-crops and resizes to fill the target size exactly.
    func autoFit(to targetSize: CGSize) -> UIImage {
        let sourceAspect = size.width / size.height
        let targetAspect = targetSize.width / targetSize.height

        var cropRect: CGRect

        if sourceAspect > targetAspect {
            // Source is wider — crop horizontally
            let newWidth = size.height * targetAspect
            let xOffset = (size.width - newWidth) / 2
            cropRect = CGRect(x: xOffset, y: 0, width: newWidth, height: size.height)
        } else {
            // Source is taller — crop vertically
            let newHeight = size.width / targetAspect
            let yOffset = (size.height - newHeight) / 2
            cropRect = CGRect(x: 0, y: yOffset, width: size.width, height: newHeight)
        }

        guard let cropped = cropped(to: cropRect) else { return self }
        return cropped.resized(to: targetSize)
    }

    /// Whether this image has an alpha channel (transparency).
    var hasAlphaChannel: Bool {
        guard let alphaInfo = cgImage?.alphaInfo else { return false }
        switch alphaInfo {
        case .first, .last, .premultipliedFirst, .premultipliedLast, .alphaOnly:
            return true
        default:
            return false
        }
    }
}
