import XCTest
@testable import GoogleChatCore

final class DeepLinkTests: XCTestCase {
    func testParseSpaceDeepLink() throws {
        let url = URL(string: "googlechatmulti://spaces/https%3A%2F%2Faccounts.google.com%7Csub-1/spaces%2FAAA")!
        let link = try DeepLinkParser.parse(url)
        guard case let .space(accountId, spaceName) = link else {
            return XCTFail("expected space link")
        }
        XCTAssertEqual(accountId.rawValue, "https://accounts.google.com|sub-1")
        XCTAssertEqual(spaceName, "spaces/AAA")
    }

    func testRejectsUnknownScheme() {
        let url = URL(string: "https://example.com/spaces/x")!
        XCTAssertThrowsError(try DeepLinkParser.parse(url))
    }
}
