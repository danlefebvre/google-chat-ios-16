import XCTest
@testable import GoogleChatMultiCore

final class DeepLinkTests: XCTestCase {
    func testParsesSpaceDeepLink() throws {
        let url = URL(string: "googlechatmulti://space/spaces%2FAAA?accountId=https%3A%2F%2Faccounts.google.com%7Csub-work")!
        let link = try DeepLinkParser.parse(url)
        guard case let .space(accountId, spaceName) = link else {
            return XCTFail("expected space link")
        }
        XCTAssertEqual(accountId.rawValue, "https://accounts.google.com|sub-work")
        XCTAssertEqual(spaceName, "spaces/AAA")
    }

    func testBuildsSpaceDeepLink() {
        let account = AccountID(issuer: "https://accounts.google.com", subject: "sub-work")
        let url = DeepLinkBuilder.spaceURL(accountId: account, spaceName: "spaces/AAA")
        XCTAssertEqual(url.scheme, "googlechatmulti")
        XCTAssertEqual(url.host, "space")
        XCTAssertTrue(url.absoluteString.contains("accountId="))
    }
}
