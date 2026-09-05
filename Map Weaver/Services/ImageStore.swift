import UIKit

/// Handles saving and loading tile asset images to/from the app's Documents directory.
final class ImageStore: Sendable {
    static let shared = ImageStore()

    private let fileManager = FileManager.default

    private var baseDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("TileImages", isDirectory: true)
    }

    private init() {}

    // MARK: - Directory Management

    private func directoryURL(for projectID: UUID) -> URL {
        baseDirectory.appendingPathComponent(projectID.uuidString, isDirectory: true)
    }

    private func ensureDirectory(for projectID: UUID) throws {
        let dir = directoryURL(for: projectID)
        if !fileManager.fileExists(atPath: dir.path) {
            try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }

    // MARK: - Save

    /// Saves a UIImage as PNG and returns the relative file path.
    func save(image: UIImage, projectID: UUID, assetID: UUID) throws -> String {
        try ensureDirectory(for: projectID)

        let relativePath = "\(projectID.uuidString)/\(assetID.uuidString).png"
        let fileURL = baseDirectory.appendingPathComponent(relativePath)

        guard let data = image.pngData() else {
            throw ImageStoreError.encodingFailed
        }
        try data.write(to: fileURL)
        return relativePath
    }

    // MARK: - Load

    func loadImage(relativePath: String) -> UIImage? {
        let fileURL = baseDirectory.appendingPathComponent(relativePath)
        guard fileManager.fileExists(atPath: fileURL.path) else { return nil }
        return UIImage(contentsOfFile: fileURL.path)
    }

    func loadImage(for asset: TileAsset) -> UIImage? {
        loadImage(relativePath: asset.imageFileName)
    }

    /// Returns the full filesystem URL for an asset's image.
    func url(for asset: TileAsset) -> URL {
        baseDirectory.appendingPathComponent(asset.imageFileName)
    }

    // MARK: - Delete

    func deleteImage(relativePath: String) {
        let fileURL = baseDirectory.appendingPathComponent(relativePath)
        try? fileManager.removeItem(at: fileURL)
    }

    func deleteProjectImages(projectID: UUID) {
        let dir = directoryURL(for: projectID)
        try? fileManager.removeItem(at: dir)
    }

    // MARK: - Copy (for import)

    func copyImage(from sourceURL: URL, projectID: UUID, assetID: UUID) throws -> String {
        try ensureDirectory(for: projectID)

        let relativePath = "\(projectID.uuidString)/\(assetID.uuidString).png"
        let destURL = baseDirectory.appendingPathComponent(relativePath)

        if fileManager.fileExists(atPath: destURL.path) {
            try fileManager.removeItem(at: destURL)
        }
        try fileManager.copyItem(at: sourceURL, to: destURL)
        return relativePath
    }
}

enum ImageStoreError: LocalizedError {
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .encodingFailed: return "Failed to encode image as PNG."
        }
    }
}
