import XCTest
@testable import GoogleChatCore

final class DeepLinkRouteTests: XCTestCase {
    let account = AccountId(issuer: "https://accounts.google.com", sub: "work")

    func testParseNtfyClickUrl() throws {
        let route = DeepLinkRoute.space(accountId: account, spaceName: "spaces/AAA")
        let url = try XCTUnwrap(route.url)
        let parsed = DeepLinkRoute.parse(url: url)
        if case .space(let acct, let space)? = parsed {
            XCTAssertEqual(acct, account)
            XCTAssertEqual(space, "spaces/AAA")
        } else {
            XCTFail("expected space route")
        }
    }

    func testRejectsUnknownScheme() {
        let url = URL(string: "https://example.com")!
        XCTAssertNil(DeepLinkRoute.parse(url: url))
    }
}
