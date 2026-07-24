import XCTest
@testable import GoogleChatCore

final class InboxMergerTests: XCTestCase {
    let merger = InboxMerger()
    let work = AccountId(issuer: "https://accounts.google.com", sub: "work")
    let home = AccountId(issuer: "https://accounts.google.com", sub: "home")

    func makeItem(
        account: AccountId,
        label: String,
        space: String,
        title: String,
        preview: String,
        minutesAgo: Int,
        unread: Bool = false
    ) -> ConversationItem {
        ConversationItem(
            accountId: account,
            accountLabel: label,
            spaceName: space,
            spaceTitle: title,
            lastMessagePreview: preview,
            lastActivity: Date(timeIntervalSinceNow: TimeInterval(-minutesAgo * 60)),
            isUnread: unread
        )
    }

    func testMergeSortsByLastActivityDescending() {
        let rows: [AccountId: [ConversationItem]] = [
            work: [
                makeItem(account: work, label: "Work", space: "spaces/A", title: "#eng", preview: "a", minutesAgo: 60),
            ],
            home: [
                makeItem(account: home, label: "Home", space: "spaces/B", title: "Family", preview: "b", minutesAgo: 2),
            ],
        ]
        let merged = merger.merge(rowsByAccount: rows)
        XCTAssertEqual(merged.count, 2)
        XCTAssertEqual(merged[0].spaceTitle, "Family")
        XCTAssertEqual(merged[1].spaceTitle, "#eng")
    }

    func testFilterByAccount() {
        let rows: [AccountId: [ConversationItem]] = [
            work: [makeItem(account: work, label: "Work", space: "spaces/A", title: "#eng", preview: "a", minutesAgo: 1)],
            home: [makeItem(account: home, label: "Home", space: "spaces/B", title: "Family", preview: "b", minutesAgo: 1)],
        ]
        let filtered = merger.merge(rowsByAccount: rows, filter: .account(work))
        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered[0].accountLabel, "Work")
    }

    func testSearchAcrossLoadedAccounts() {
        let rows: [AccountId: [ConversationItem]] = [
            work: [makeItem(account: work, label: "Work", space: "spaces/A", title: "#eng-standup", preview: "deploy looks good", minutesAgo: 1)],
            home: [makeItem(account: home, label: "Home", space: "spaces/B", title: "Family", preview: "dinner at 7?", minutesAgo: 5)],
        ]
        let results = merger.merge(rowsByAccount: rows, searchQuery: "dinner")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].spaceTitle, "Family")
    }

    func testCompositeIdUsesSpaceResourceName() {
        let item = makeItem(account: work, label: "Work", space: "spaces/AAA", title: "Renamed", preview: "x", minutesAgo: 1)
        XCTAssertEqual(item.id, "\(work.rawValue):spaces/AAA")
    }

    func testUpsertReplacesExistingSpaceRow() {
        let existing = [
            makeItem(account: work, label: "Work", space: "spaces/A", title: "Old", preview: "old", minutesAgo: 10),
        ]
        let space = ChatSpace(name: "spaces/A", displayName: "New Title")
        let msg = ChatMessage(
            name: "spaces/A/messages/1",
            spaceName: "spaces/A",
            text: "new message",
            senderDisplayName: "Alice",
            createTime: Date()
        )
        let updated = merger.upsert(
            rows: existing,
            accountId: work,
            accountLabel: "Work",
            space: space,
            latestMessage: msg,
            isUnread: true
        )
        XCTAssertEqual(updated.count, 1)
        XCTAssertEqual(updated[0].spaceTitle, "New Title")
        XCTAssertTrue(updated[0].lastMessagePreview.contains("Alice"))
        XCTAssertTrue(updated[0].isUnread)
    }
}
