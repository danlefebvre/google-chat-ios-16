import XCTest
@testable import GoogleChatCore

final class AccountStoreTests: XCTestCase {
    func testSaveAndLoadAccounts() throws {
        let store = InMemoryAccountStore()
        let account = StoredAccount(
            accountId: AccountId(issuer: "https://accounts.google.com", subject: "1"),
            label: "Work",
            color: .work,
            accessToken: "access",
            refreshToken: "refresh",
            expiresAt: Date(timeIntervalSince1970: 9_999_999)
        )

        try store.save(account)
        let loaded = try store.loadAll()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].label, "Work")
    }

    func testRemoveAccount() throws {
        let store = InMemoryAccountStore()
        let id = AccountId(issuer: "https://accounts.google.com", subject: "1")
        let account = StoredAccount(
            accountId: id,
            label: "Work",
            color: .work,
            accessToken: "access",
            refreshToken: "refresh",
            expiresAt: Date()
        )
        try store.save(account)
        try store.remove(accountId: id)
        XCTAssertTrue(try store.loadAll().isEmpty)
    }
}
