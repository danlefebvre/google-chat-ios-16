import XCTest
@testable import GoogleChatCore

final class AuthorizationStoreTests: XCTestCase {
    func testSaveLoadDelete() throws {
        let store = InMemoryAuthorizationStore()
        let accountId = AccountId(issuer: "iss", sub: "sub")
        let auth = StoredAuthorization(
            accountId: accountId,
            accessToken: "access",
            refreshToken: "refresh",
            expiresAt: Date().addingTimeInterval(3600)
        )

        try store.save(auth)
        XCTAssertEqual(try store.load(accountId: accountId), auth)
        XCTAssertEqual(try store.listAccountIds(), [accountId])

        try store.delete(accountId: accountId)
        XCTAssertNil(try store.load(accountId: accountId))
    }

    func testIsExpired() {
        let accountId = AccountId(issuer: "iss", sub: "sub")
        let expired = StoredAuthorization(
            accountId: accountId,
            accessToken: "a",
            refreshToken: "r",
            expiresAt: Date().addingTimeInterval(-1)
        )
        XCTAssertTrue(expired.isExpired)
    }
}

final class OAuthScopesTests: XCTestCase {
    func testMinimalScopesIncludeChat() {
        XCTAssertTrue(OAuthScopes.minimal.contains("https://www.googleapis.com/auth/chat.messages"))
    }
}
