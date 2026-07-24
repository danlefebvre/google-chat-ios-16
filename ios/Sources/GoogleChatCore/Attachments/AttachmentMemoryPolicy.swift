import Foundation

public struct AttachmentMemoryPolicy: Sendable, Equatable {
    public var maxDecodedThumbnailBytes: Int
    public var maxConcurrentDecodes: Int
    public var maxCachedThumbnails: Int
    public var maxThumbnailEdge: Int

    public init(
        maxDecodedThumbnailBytes: Int,
        maxConcurrentDecodes: Int,
        maxCachedThumbnails: Int,
        maxThumbnailEdge: Int
    ) {
        self.maxDecodedThumbnailBytes = maxDecodedThumbnailBytes
        self.maxConcurrentDecodes = maxConcurrentDecodes
        self.maxCachedThumbnails = maxCachedThumbnails
        self.maxThumbnailEdge = maxThumbnailEdge
    }

    /// Conservative defaults for iPhone 8 (2 GB RAM).
    public static let iPhone8 = AttachmentMemoryPolicy(
        maxDecodedThumbnailBytes: 512 * 1024,
        maxConcurrentDecodes: 2,
        maxCachedThumbnails: 40,
        maxThumbnailEdge: 512
    )

    public func shouldDownsample(pixelWidth: Int, pixelHeight: Int) -> Bool {
        let bytes = pixelWidth * pixelHeight * 4
        return bytes > maxDecodedThumbnailBytes
            || pixelWidth > maxThumbnailEdge
            || pixelHeight > maxThumbnailEdge
    }

    public func targetThumbnailSize(pixelWidth: Int, pixelHeight: Int) -> (width: Int, height: Int) {
        guard pixelWidth > 0, pixelHeight > 0 else {
            return (maxThumbnailEdge, maxThumbnailEdge)
        }
        let maxEdge = Double(maxThumbnailEdge)
        let w = Double(pixelWidth)
        let h = Double(pixelHeight)
        let scale = min(1.0, maxEdge / max(w, h))
        return (width: max(1, Int((w * scale).rounded())), height: max(1, Int((h * scale).rounded())))
    }
}
