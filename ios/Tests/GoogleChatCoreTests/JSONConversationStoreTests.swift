import XCTest
@testable import GoogleChatCore

final class JSONConversationStoreTests: XCTestCase {
    func testPersistsAndUpserts() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = try JSONConversationStore(directory: dir)
        let accountId = AccountID(issuer: "https://accounts.google.com", subject: "work")
        try store.upsert(ConversationSummary(
            accountId: accountId,
            spaceName: "spaces/A",
            title: "Old",
            lastMessagePreview: "a",
            lastActivityAt: Date(timeIntervalSince1970: 1),
            unreadCount: 1,
            accountLabel: "Work",
            badgeColorHex: "#C45C26"
        ))
        try store.upsert(ConversationSummary(
            accountId: accountId,
            spaceName: "spaces/A",
            title: "New",
            lastMessagePreview: "b",
            lastActivityAt: Date(timeIntervalSince1970: 2),
            unreadCount: 0,
            accountLabel: "Work",
            badgeColorHex: "#C45C26"
        ))

        let reopened = try JSONConversationStore(directory: dir)
        let all = reopened.all()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all[0].title, "New")
    }
}
