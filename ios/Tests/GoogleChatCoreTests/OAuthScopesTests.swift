import XCTest
@testable import GoogleChatCore

final class OAuthScopesTests: XCTestCase {
    func testMVPIncludesChatAndIdentityScopes() {
        XCTAssertTrue(OAuthScopes.mvp.contains(OAuthScopes.openID))
        XCTAssertTrue(OAuthScopes.mvp.contains(OAuthScopes.chatMessages))
        XCTAssertTrue(OAuthScopes.mvp.contains(OAuthScopes.chatUsersReadState))
        XCTAssertTrue(OAuthScopes.mvp.contains(OAuthScopes.chatSpacesReadonly))
    }
}
