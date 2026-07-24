import XCTest
@testable import GoogleChatCore

final class AccountStoreTests: XCTestCase {
    func testUpsertSupportsNAccounts() {
        var store = InMemoryAccountStore()
        let a = Account(
            id: AccountID(issuer: "https://accounts.google.com", subject: "1"),
            email: "a@example.com",
            label: "Personal",
            badgeColorHex: "#2E8B57"
        )
        let b = Account(
            id: AccountID(issuer: "https://accounts.google.com", subject: "2"),
            email: "b@example.com",
            label: "Work",
            badgeColorHex: "#3366FF"
        )
        store.upsert(a)
        store.upsert(b)
        XCTAssertEqual(store.all().count, 2)
    }

    func testRemoveDeletesAccount() {
        var store = InMemoryAccountStore()
        let id = AccountID(issuer: "https://accounts.google.com", subject: "1")
        store.upsert(Account(id: id, email: "a@example.com", label: "Personal", badgeColorHex: "#2E8B57"))
        store.remove(id)
        XCTAssertTrue(store.all().isEmpty)
    }
}
