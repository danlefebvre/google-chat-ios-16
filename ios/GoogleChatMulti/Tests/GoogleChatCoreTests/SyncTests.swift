import XCTest
@testable import GoogleChatCore

final class ConversationUpserterTests: XCTestCase {
    private let accountId = AccountId(issuer: "iss", sub: "sub")

    private func summary(space: String, title: String, activity: TimeInterval) -> ConversationSummary {
        ConversationSummary(
            conversationId: ConversationId(accountId: accountId, spaceName: space),
            accountLabel: "Work",
            title: title,
            lastMessagePreview: "preview",
            lastActivity: Date(timeIntervalSince1970: activity),
            unread: false
        )
    }

    func testUpsertReplacesExistingConversation() {
        let upserter = ConversationUpserter()
        let original = summary(space: "spaces/AAA", title: "Old title", activity: 100)
        let updated = summary(space: "spaces/AAA", title: "New title", activity: 200)

        let result = upserter.upsert(existing: [original], incoming: updated)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.title, "New title")
    }

    func testUpsertManyMergesByConversationId() {
        let upserter = ConversationUpserter()
        let a = summary(space: "spaces/A", title: "A", activity: 100)
        let b = summary(space: "spaces/B", title: "B", activity: 150)
        let bUpdated = summary(space: "spaces/B", title: "B2", activity: 250)

        let result = upserter.upsertMany(existing: [a, b], incoming: [bUpdated])
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result.first { $0.title.hasPrefix("B") }?.title, "B2")
    }
}
