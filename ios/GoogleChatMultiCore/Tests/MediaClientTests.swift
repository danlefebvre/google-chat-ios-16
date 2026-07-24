import XCTest
@testable import GoogleChatMultiCore

final class MediaClientTests: XCTestCase {
    func testTooLargeErrorEquatable() {
        XCTAssertEqual(MediaClientError.tooLarge(10, 5), MediaClientError.tooLarge(10, 5))
        XCTAssertNotEqual(MediaClientError.tooLarge(10, 5), MediaClientError.tooLarge(11, 5))
    }

    func testDefaultMaxBytesMatchesIPhone8Budget() {
        let client = MediaClient()
        XCTAssertEqual(client.maxBytes, 1_500_000)
    }
}
