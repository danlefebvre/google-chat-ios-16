import Foundation

/// Memory-safe attachment limits tuned for iPhone 8 (2 GB RAM).
public enum AttachmentPolicy {
    public static let maxThumbnailBytes = 256 * 1024
    public static let maxInMemoryAttachments = 3
    public static let downsampleThresholdBytes = 512 * 1024

    public static func shouldDownsample(byteCount: Int, contentType: String) -> Bool {
        contentType.hasPrefix("image/") && byteCount >= downsampleThresholdBytes
    }
}
