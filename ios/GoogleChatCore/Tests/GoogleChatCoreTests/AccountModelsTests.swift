import XCTest
@testable import GoogleChatCore

final class AccountModelsTests: XCTestCase {
    func testAccountIdRawValue() {
        let id = AccountId(issuer: "https://accounts.google.com", sub: "abc123")
        XCTAssertEqual(id.rawValue, "https://accounts.google.com|abc123")
    }

    func testAccountIdParseRoundTrip() {
        let raw = "https://accounts.google.com|abc123"
        let parsed = AccountId.parse(raw)
        XCTAssertEqual(parsed?.rawValue, raw)
    }

    func testAccountIdParseRejectsInvalid() {
        XCTAssertNil(AccountId.parse("no-pipe"))
        XCTAssertNil(AccountId.parse("|missing-issuer"))
    }

    func testOAuthScopesIncludeChatAPI() {
        XCTAssertTrue(OAuthScopes.all.contains("https://www.googleapis.com/auth/chat.messages"))
        XCTAssertTrue(OAuthScopes.spaceDelimited.contains("openid"))
    }
}
