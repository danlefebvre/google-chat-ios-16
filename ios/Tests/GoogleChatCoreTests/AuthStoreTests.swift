import XCTest
@testable import GoogleChatCore

final class AuthStoreTests: XCTestCase {
    func testUpsertMultipleAccounts() async throws {
        let store = InMemoryAuthStore()
        let work = AccountAuthorization(
            accountID: AccountID(issuer: "iss", subject: "work", email: "w@ex.com"),
            label: "Work",
            refreshToken: "rt-work",
            accessToken: "at-work",
            accessTokenExpiresAt: Date().addingTimeInterval(3600)
        )
        let home = AccountAuthorization(
            accountID: AccountID(issuer: "iss", subject: "home", email: "h@ex.com"),
            label: "Personal",
            refreshToken: "rt-home",
            accessToken: "at-home",
            accessTokenExpiresAt: Date().addingTimeInterval(3600)
        )
        try await store.upsert(work)
        try await store.upsert(home)
        let all = try await store.all()
        XCTAssertEqual(all.count, 2)
        XCTAssertEqual(Set(all.map(\.accountID.subject)), Set(["work", "home"]))
    }

    func testRemoveAccount() async throws {
        let store = InMemoryAuthStore()
        let id = AccountID(issuer: "iss", subject: "work")
        try await store.upsert(AccountAuthorization(
            accountID: id, label: "Work", refreshToken: "rt",
            accessToken: "at", accessTokenExpiresAt: Date().addingTimeInterval(60)
        ))
        try await store.remove(id)
        let all = try await store.all()
        XCTAssertTrue(all.isEmpty)
    }

    func testTokenProviderRefreshesExpiredAccessToken() async throws {
        let id = AccountID(issuer: "iss", subject: "work")
        let store = InMemoryAuthStore()
        try await store.upsert(AccountAuthorization(
            accountID: id, label: "Work", refreshToken: "rt",
            accessToken: "old", accessTokenExpiresAt: Date().addingTimeInterval(-10)
        ))
        let refresher = MockTokenRefresher { refresh in
            XCTAssertEqual(refresh, "rt")
            return ("new-access", Date().addingTimeInterval(3600))
        }
        let provider = TokenProvider(store: store, refresher: refresher)
        let token = try await provider.validAccessToken(for: id)
        XCTAssertEqual(token, "new-access")
        let saved = try await store.authorization(for: id)
        XCTAssertEqual(saved?.accessToken, "new-access")
    }
}
