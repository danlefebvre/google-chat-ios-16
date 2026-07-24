import XCTest
@testable import GoogleChatCore

final class AuthStoreTests: XCTestCase {
    func testSupportsNAccountsKeyedBySubject() throws {
        let store = InMemoryAuthStore()
        let a = StoredAuthorization(
            account: Account(
                id: AccountID(issuer: "https://accounts.google.com", subject: "1"),
                email: "personal@gmail.com",
                displayName: "Personal",
                label: "Home",
                badgeColorHex: "#2F6F4E"
            ),
            refreshToken: "r1",
            accessToken: "a1",
            expiry: Date().addingTimeInterval(3600)
        )
        let b = StoredAuthorization(
            account: Account(
                id: AccountID(issuer: "https://accounts.google.com", subject: "2"),
                email: "work@example.com",
                displayName: "Work",
                label: "Work",
                badgeColorHex: "#C45C26"
            ),
            refreshToken: "r2",
            accessToken: "a2",
            expiry: Date().addingTimeInterval(3600)
        )
        try store.save(a)
        try store.save(b)
        XCTAssertEqual(store.all().count, 2)
        try store.remove(id: a.account.id)
        XCTAssertEqual(store.all().map(\.account.email), ["work@example.com"])
    }

    func testNeedsRefreshWhenExpired() {
        let auth = StoredAuthorization(
            account: Account(
                id: AccountID(issuer: "https://accounts.google.com", subject: "1"),
                email: "a@b.c",
                displayName: "A",
                label: "Home",
                badgeColorHex: "#2F6F4E"
            ),
            refreshToken: "r",
            accessToken: "a",
            expiry: Date().addingTimeInterval(-10)
        )
        XCTAssertTrue(auth.needsRefresh(at: Date()))
    }
}
