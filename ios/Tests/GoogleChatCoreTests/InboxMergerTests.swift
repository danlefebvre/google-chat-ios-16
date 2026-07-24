import XCTest
@testable import GoogleChatCore

final class InboxMergerTests: XCTestCase {
    func testMergeSortsByLastActivityDescending() {
        let work = AccountID(issuer: "https://accounts.google.com", subject: "work")
        let home = AccountID(issuer: "https://accounts.google.com", subject: "home")
        let older = ConversationSummary(
            accountId: work,
            spaceName: "spaces/AAA",
            title: "#eng-standup",
            lastMessagePreview: "Alice: deploy looks good",
            lastActivityAt: Date(timeIntervalSince1970: 100),
            unreadCount: 1,
            accountLabel: "Work",
            badgeColorHex: "#C45C26"
        )
        let newer = ConversationSummary(
            accountId: home,
            spaceName: "spaces/BBB",
            title: "Family",
            lastMessagePreview: "Mom: dinner at 7?",
            lastActivityAt: Date(timeIntervalSince1970: 200),
            unreadCount: 0,
            accountLabel: "Home",
            badgeColorHex: "#2F6F4E"
        )

        let merged = InboxMerger.merge(conversations: [older, newer], filter: .all)
        XCTAssertEqual(merged.map(\.compositeId), [newer.compositeId, older.compositeId])
    }

    func testCompositeIdUsesImmutableSpaceNameNotTitle() {
        let id = AccountID(issuer: "https://accounts.google.com", subject: "work")
        let a = ConversationSummary(
            accountId: id,
            spaceName: "spaces/AAA",
            title: "Old Name",
            lastMessagePreview: "hi",
            lastActivityAt: Date(),
            unreadCount: 0,
            accountLabel: "Work",
            badgeColorHex: "#C45C26"
        )
        let b = ConversationSummary(
            accountId: id,
            spaceName: "spaces/AAA",
            title: "Renamed",
            lastMessagePreview: "hi",
            lastActivityAt: Date(),
            unreadCount: 0,
            accountLabel: "Work",
            badgeColorHex: "#C45C26"
        )
        XCTAssertEqual(a.compositeId, b.compositeId)
        XCTAssertEqual(a.compositeId, "\(id.rawValue):spaces/AAA")
    }

    func testFilterByAccountLabel() {
        let work = AccountID(issuer: "https://accounts.google.com", subject: "work")
        let home = AccountID(issuer: "https://accounts.google.com", subject: "home")
        let rows = [
            ConversationSummary(
                accountId: work, spaceName: "spaces/A", title: "A",
                lastMessagePreview: "x", lastActivityAt: Date(timeIntervalSince1970: 2),
                unreadCount: 0, accountLabel: "Work", badgeColorHex: "#C45C26"
            ),
            ConversationSummary(
                accountId: home, spaceName: "spaces/B", title: "B",
                lastMessagePreview: "y", lastActivityAt: Date(timeIntervalSince1970: 1),
                unreadCount: 0, accountLabel: "Home", badgeColorHex: "#2F6F4E"
            ),
        ]
        let filtered = InboxMerger.merge(conversations: rows, filter: .accountLabel("Work"))
        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered[0].title, "A")
    }

    func testSearchMatchesTitleAndPreview() {
        let id = AccountID(issuer: "https://accounts.google.com", subject: "work")
        let rows = [
            ConversationSummary(
                accountId: id, spaceName: "spaces/A", title: "#eng-standup",
                lastMessagePreview: "deploy looks good", lastActivityAt: Date(),
                unreadCount: 0, accountLabel: "Work", badgeColorHex: "#C45C26"
            ),
            ConversationSummary(
                accountId: id, spaceName: "spaces/B", title: "Random",
                lastMessagePreview: "unrelated", lastActivityAt: Date(),
                unreadCount: 0, accountLabel: "Work", badgeColorHex: "#C45C26"
            ),
        ]
        let byTitle = InboxMerger.search(conversations: rows, query: "eng")
        XCTAssertEqual(byTitle.count, 1)
        let byPreview = InboxMerger.search(conversations: rows, query: "DEPLOY")
        XCTAssertEqual(byPreview.count, 1)
    }
}
