import Foundation
#if canImport(UIKit)
import UIKit
#endif

enum AttachmentMemory {
    /// Downscales / recompresses image payloads for iPhone 8 memory limits.
    static func limitImageData(_ data: Data, maxBytes: Int) -> Data {
        guard data.count > maxBytes else { return data }
        #if canImport(UIKit)
        guard let image = UIImage(data: data) else { return Data(data.prefix(maxBytes)) }
        var quality: CGFloat = 0.8
        var current = image
        while quality > 0.2 {
            let size = current.size
            let scale = min(1.0, sqrt(CGFloat(maxBytes) / CGFloat(max(data.count, 1))))
            let newSize = CGSize(width: size.width * scale, height: size.height * scale)
            let renderer = UIGraphicsImageRenderer(size: newSize)
            let rendered = renderer.image { _ in
                current.draw(in: CGRect(origin: .zero, size: newSize))
            }
            if let jpeg = rendered.jpegData(compressionQuality: quality), jpeg.count <= maxBytes {
                return jpeg
            }
            current = rendered
            quality -= 0.15
        }
        return current.jpegData(compressionQuality: 0.2) ?? Data(data.prefix(maxBytes))
        #else
        return Data(data.prefix(maxBytes))
        #endif
    }
}
