import XCTest
@testable import GoogleChatCore

final class TokenStoreTests: XCTestCase {
    func testSaveLoadDelete() throws {
        let store = InMemoryTokenStore()
        let id = AccountID(issuer: "https://accounts.google.com", subject: "1")
        try store.save(accountID: id, tokens: AuthTokens(accessToken: "a", refreshToken: "r"))
        XCTAssertEqual(try store.load(accountID: id)?.accessToken, "a")
        try store.delete(accountID: id)
        XCTAssertNil(try store.load(accountID: id))
    }

    func testExpiryDetection() {
        let expired = AuthTokens(
            accessToken: "a",
            refreshToken: "r",
            expiry: Date().addingTimeInterval(-10)
        )
        XCTAssertTrue(expired.isExpired)
        let fresh = AuthTokens(
            accessToken: "a",
            refreshToken: "r",
            expiry: Date().addingTimeInterval(600)
        )
        XCTAssertFalse(fresh.isExpired)
    }
}
