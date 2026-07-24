import XCTest
@testable import GoogleChatCore

final class AccountStoreTests: XCTestCase {
    func testUpsertSupportsNAccounts() throws {
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
        try store.upsert(a)
        try store.upsert(b)
        XCTAssertEqual(store.all().count, 2)
    }

    func testRemoveDeletesAccount() throws {
        var store = InMemoryAccountStore()
        let id = AccountID(issuer: "https://accounts.google.com", subject: "1")
        try store.upsert(Account(id: id, email: "a@example.com", label: "Personal", badgeColorHex: "#2E8B57"))
        try store.remove(id)
        XCTAssertTrue(store.all().isEmpty)
    }

    func testJSONFileAccountStorePersistsAcrossReopen() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("accounts-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }

        let account = Account(
            id: AccountID(issuer: "https://accounts.google.com", subject: "work"),
            email: "work@example.com",
            label: "Work",
            badgeColorHex: "#3366FF"
        )
        var store = try JSONFileAccountStore(fileURL: url)
        try store.upsert(account)

        let reopened = try JSONFileAccountStore(fileURL: url)
        XCTAssertEqual(reopened.all().map(\.label), ["Work"])
    }
}
