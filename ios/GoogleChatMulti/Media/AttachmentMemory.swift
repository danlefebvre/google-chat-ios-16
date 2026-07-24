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
        let scale = min(1.0, sqrt(CGFloat(maxBytes) / CGFloat(max(data.count, 1))))
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let scaled = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        var quality: CGFloat = 0.8
        while quality > 0.2 {
            if let jpeg = scaled.jpegData(compressionQuality: quality), jpeg.count <= maxBytes {
                return jpeg
            }
            quality -= 0.15
        }
        return scaled.jpegData(compressionQuality: 0.2) ?? Data(data.prefix(maxBytes))
        #else
        return Data(data.prefix(maxBytes))
        #endif
    }
}
