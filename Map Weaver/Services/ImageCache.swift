import UIKit

/// In-memory cache for tile images, backed by NSCache for automatic eviction under memory pressure.
final class ImageCache: @unchecked Sendable {
    static let shared = ImageCache()

    private let cache = NSCache<NSString, UIImage>()

    private init() {
        cache.countLimit = 500
    }

    func image(for asset: TileAsset) -> UIImage? {
        let key = asset.id.uuidString as NSString

        if let cached = cache.object(forKey: key) {
            return cached
        }

        guard let loaded = ImageStore.shared.loadImage(for: asset) else { return nil }
        cache.setObject(loaded, forKey: key)
        return loaded
    }

    func preload(assets: [TileAsset]) {
        for asset in assets {
            _ = image(for: asset)
        }
    }

    func invalidate(for asset: TileAsset) {
        cache.removeObject(forKey: asset.id.uuidString as NSString)
    }

    func clearAll() {
        cache.removeAllObjects()
    }
}
