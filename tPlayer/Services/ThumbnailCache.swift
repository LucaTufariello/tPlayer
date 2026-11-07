import AppKit

final class ThumbnailCache {
    static let shared = ThumbnailCache()

    private let cache = NSCache<NSString, NSImage>()

    private init() {
        cache.countLimit = 160
        cache.totalCostLimit = 220 * 1024 * 1024
    }

    func image(for film: Film) -> NSImage? {
        guard let url = film.thumbnailURL else { return nil }
        let key = url.path as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }
        guard let image = NSImage(contentsOf: url) else { return nil }
        cache.setObject(image, forKey: key)
        return image
    }

    func invalidate(for film: Film) {
        guard let url = film.thumbnailURL else { return }
        cache.removeObject(forKey: url.path as NSString)
    }
}
