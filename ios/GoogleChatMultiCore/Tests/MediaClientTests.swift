import XCTest
@testable import GoogleChatMultiCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

final class MediaClientTests: XCTestCase {
    func testDefaultInitUsesSharedSession() {
        let client = MediaClient()
        XCTAssertTrue(client.session === URLSession.shared)
    }
}
