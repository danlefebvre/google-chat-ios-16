import XCTest
@testable import GoogleChatCore

final class AttachmentPolicyTests: XCTestCase {
    func testThumbnailBudgetForiPhone8() {
        let policy = AttachmentMemoryPolicy.iPhone8
        XCTAssertEqual(policy.maxDecodedThumbnailBytes, 512 * 1024)
        XCTAssertEqual(policy.maxConcurrentDecodes, 2)
        XCTAssertEqual(policy.maxCachedThumbnails, 40)
    }

    func testShouldDownsampleWhenPixelBudgetExceeded() {
        let policy = AttachmentMemoryPolicy.iPhone8
        XCTAssertTrue(policy.shouldDownsample(pixelWidth: 4000, pixelHeight: 3000))
        XCTAssertFalse(policy.shouldDownsample(pixelWidth: 320, pixelHeight: 240))
    }

    func testTargetSizeKeepsAspectRatio() {
        let policy = AttachmentMemoryPolicy.iPhone8
        let size = policy.targetThumbnailSize(pixelWidth: 4000, pixelHeight: 2000)
        XCTAssertEqual(size.width, policy.maxThumbnailEdge)
        XCTAssertEqual(size.height, policy.maxThumbnailEdge / 2)
    }
}
