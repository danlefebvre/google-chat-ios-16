import XCTest
@testable import GoogleChatCore

final class AttachmentPolicyTests: XCTestCase {
    func testThumbnailByteBudgetFitsIPhone8() {
        // Keep decoded thumbnail budgets tiny for 2 GB devices.
        XCTAssertLessThanOrEqual(AttachmentPolicy.maxThumbnailBytes, 512 * 1024)
        XCTAssertLessThanOrEqual(AttachmentPolicy.maxInMemoryAttachments, 3)
    }

    func testShouldDownsampleLargeImages() {
        XCTAssertTrue(AttachmentPolicy.shouldDownsample(byteCount: 2_000_000, contentType: "image/jpeg"))
        XCTAssertFalse(AttachmentPolicy.shouldDownsample(byteCount: 20_000, contentType: "image/png"))
        XCTAssertFalse(AttachmentPolicy.shouldDownsample(byteCount: 5_000_000, contentType: "application/pdf"))
    }
}
