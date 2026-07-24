import XCTest
@testable import GoogleChatCore

final class SyncUpsertTests: XCTestCase {
    func testUpsertReplacesByConversationID() throws {
        let account = AccountID(issuer: "https://accounts.google.com", subject: "work")
        let id = ConversationID(accountID: account, spaceName: "spaces/AAA")
        var store = InMemoryConversationStore()
        try store.upsert([
            Conversation(
                id: id,
                title: "Old",
                lastMessagePreview: "a",
                lastActivityAt: Date(timeIntervalSince1970: 1),
                unread: true,
                accountLabel: "Work",
                badgeColorHex: "#3366FF"
            )
        ])
        try store.upsert([
            Conversation(
                id: id,
                title: "New",
                lastMessagePreview: "b",
                lastActivityAt: Date(timeIntervalSince1970: 2),
                unread: false,
                accountLabel: "Work",
                badgeColorHex: "#3366FF"
            )
        ])

        let all = store.all()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all[0].title, "New")
        XCTAssertEqual(all[0].lastMessagePreview, "b")
        XCTAssertFalse(all[0].unread)
    }

    func testRemoveAccountWipesOnlyThatAccountsRows() throws {
        let work = AccountID(issuer: "https://accounts.google.com", subject: "work")
        let home = AccountID(issuer: "https://accounts.google.com", subject: "home")
        var store = InMemoryConversationStore()
        try store.upsert([
            Conversation(
                id: ConversationID(accountID: work, spaceName: "spaces/1"),
                title: "W",
                lastMessagePreview: "a",
                lastActivityAt: Date(timeIntervalSince1970: 2),
                unread: false,
                accountLabel: "Work",
                badgeColorHex: "#3366FF"
            ),
            Conversation(
                id: ConversationID(accountID: home, spaceName: "spaces/2"),
                title: "H",
                lastMessagePreview: "b",
                lastActivityAt: Date(timeIntervalSince1970: 1),
                unread: false,
                accountLabel: "Personal",
                badgeColorHex: "#2E8B57"
            ),
        ])
        try store.removeAll(for: work)
        XCTAssertEqual(store.all().map(\.title), ["H"])
    }
}
