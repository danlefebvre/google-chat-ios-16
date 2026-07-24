import XCTest
@testable import GoogleChatCore

final class OAuthScopesTests: XCTestCase {
    func testIncludesChatAndOpenID() {
        XCTAssertTrue(OAuthScopes.all.contains("openid"))
        XCTAssertTrue(OAuthScopes.all.contains("https://www.googleapis.com/auth/chat.messages"))
        XCTAssertTrue(OAuthScopes.spaceSeparated.contains("chat.users.readstate"))
    }
}
