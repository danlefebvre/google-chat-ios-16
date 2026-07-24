import Foundation

/// Memory-safe limits for iPhone 8 (A11 / 2 GB RAM).
public enum AttachmentPolicy {
    public static let maxThumbnailDimension: Int = 512
    public static let maxInMemoryBytes: Int = 4 * 1024 * 1024
    public static let maxUploadBytes: Int = 25 * 1024 * 1024

    public static func allowsUpload(byteCount: Int) -> Bool {
        byteCount > 0 && byteCount <= maxUploadBytes
    }

    public static func shouldDownsample(byteCount: Int) -> Bool {
        byteCount > maxInMemoryBytes
    }
}
