import XCTest
@testable import GoogleChatCore

final class SyncUpsertTests: XCTestCase {
    func testUpsertReplacesSameCompositeId() {
        let accountId = AccountID(issuer: "https://accounts.google.com", subject: "work")
        let cache = InMemoryConversationStore()
        let first = ConversationSummary(
            accountId: accountId, spaceName: "spaces/A", title: "Old",
            lastMessagePreview: "a", lastActivityAt: Date(timeIntervalSince1970: 1),
            unreadCount: 1, accountLabel: "Work", badgeColorHex: "#C45C26"
        )
        let second = ConversationSummary(
            accountId: accountId, spaceName: "spaces/A", title: "New",
            lastMessagePreview: "b", lastActivityAt: Date(timeIntervalSince1970: 2),
            unreadCount: 0, accountLabel: "Work", badgeColorHex: "#C45C26"
        )
        cache.upsert(first)
        cache.upsert(second)
        let all = cache.all()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all[0].title, "New")
        XCTAssertEqual(all[0].unreadCount, 0)
    }
}
