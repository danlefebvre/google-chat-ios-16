import XCTest
@testable import GoogleChatCore

final class InboxMergerTests: XCTestCase {
    private let accountA = AccountId(issuer: "iss", sub: "a")
    private let accountB = AccountId(issuer: "iss", sub: "b")

    private func summary(
        accountId: AccountId,
        label: String,
        space: String,
        title: String,
        preview: String,
        activity: Date,
        unread: Bool = false
    ) -> ConversationSummary {
        ConversationSummary(
            conversationId: ConversationId(accountId: accountId, spaceName: space),
            accountLabel: label,
            title: title,
            lastMessagePreview: preview,
            lastActivity: activity,
            unread: unread
        )
    }

    func testMergeSortsByLastActivityDescending() {
        let older = summary(
            accountId: accountA,
            label: "Work",
            space: "spaces/1",
            title: "Old",
            preview: "a",
            activity: Date(timeIntervalSince1970: 100)
        )
        let newer = summary(
            accountId: accountB,
            label: "Home",
            space: "spaces/2",
            title: "New",
            preview: "b",
            activity: Date(timeIntervalSince1970: 200)
        )

        let merged = InboxMerger().merge([older, newer])
        XCTAssertEqual(merged.map(\.title), ["New", "Old"])
    }

    func testFilterByAccount() {
        let work = summary(
            accountId: accountA,
            label: "Work",
            space: "spaces/1",
            title: "Standup",
            preview: "hi",
            activity: Date()
        )
        let home = summary(
            accountId: accountB,
            label: "Home",
            space: "spaces/2",
            title: "Family",
            preview: "dinner",
            activity: Date()
        )

        let filtered = InboxMerger().filter([work, home], by: .account(accountA))
        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered.first?.title, "Standup")
    }

    func testSearchMatchesTitleAndPreview() {
        let items = [
            summary(
                accountId: accountA,
                label: "Work",
                space: "spaces/1",
                title: "#eng-standup",
                preview: "deploy looks good",
                activity: Date()
            ),
            summary(
                accountId: accountB,
                label: "Home",
                space: "spaces/2",
                title: "Family",
                preview: "dinner at 7",
                activity: Date()
            ),
        ]

        let results = InboxMerger().search(items, query: "deploy")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.title, "#eng-standup")
    }
}

final class MessagePreviewFormatterTests: XCTestCase {
    func testTruncatesLongPreview() {
        let long = String(repeating: "x", count: 100)
        let preview = MessagePreviewFormatter().preview(senderName: "Alice", text: long, maxLength: 20)
        XCTAssertTrue(preview.hasSuffix("…"))
        XCTAssertLessThanOrEqual(preview.count, 20)
    }
}
