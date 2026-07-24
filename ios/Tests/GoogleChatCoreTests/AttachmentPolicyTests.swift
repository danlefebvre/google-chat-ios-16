import XCTest
@testable import GoogleChatCore

final class AttachmentPolicyTests: XCTestCase {
    func testThumbnailPixelBudgetForIPhone8() {
        // Keep decoded thumbnails small on 2GB devices.
        XCTAssertEqual(AttachmentPolicy.maxThumbnailDimension, 512)
        XCTAssertEqual(AttachmentPolicy.maxInMemoryBytes, 4 * 1024 * 1024)
    }

    func testRejectsOversizedUpload() {
        XCTAssertTrue(AttachmentPolicy.allowsUpload(byteCount: 1_000_000))
        XCTAssertFalse(AttachmentPolicy.allowsUpload(byteCount: 30 * 1024 * 1024))
    }
}
