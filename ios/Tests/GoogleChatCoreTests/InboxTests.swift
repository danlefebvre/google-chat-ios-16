import XCTest
@testable import GoogleChatCore

final class InboxTests: XCTestCase {
    func testMergeSortsByLastActivityDescending() {
        let work = AccountID(issuer: "iss", subject: "work", email: "w@ex.com")
        let home = AccountID(issuer: "iss", subject: "home", email: "h@ex.com")
        let rows = [
            ConversationSummary(
                accountID: home,
                accountLabel: "Personal",
                spaceName: "spaces/fam",
                title: "Family",
                lastMessagePreview: "Mom: dinner?",
                lastActivityAt: Date(timeIntervalSince1970: 100),
                unreadCount: 1,
                isDM: false
            ),
            ConversationSummary(
                accountID: work,
                accountLabel: "Work",
                spaceName: "spaces/eng",
                title: "#eng-standup",
                lastMessagePreview: "Alice: deploy looks good",
                lastActivityAt: Date(timeIntervalSince1970: 200),
                unreadCount: 0,
                isDM: false
            ),
        ]

        let merged = InboxMerger.merge(rows)
        XCTAssertEqual(merged.map(\.compositeID), ["iss|work:spaces/eng", "iss|home:spaces/fam"])
    }

    func testFilterByAccount() {
        let work = AccountID(issuer: "iss", subject: "work")
        let home = AccountID(issuer: "iss", subject: "home")
        let rows = [
            ConversationSummary(
                accountID: work, accountLabel: "Work", spaceName: "spaces/a",
                title: "A", lastMessagePreview: "", lastActivityAt: Date(), unreadCount: 0, isDM: false
            ),
            ConversationSummary(
                accountID: home, accountLabel: "Personal", spaceName: "spaces/b",
                title: "B", lastMessagePreview: "", lastActivityAt: Date(), unreadCount: 0, isDM: true
            ),
        ]
        let filtered = InboxMerger.filter(rows, accountID: work)
        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered[0].title, "A")
    }

    func testSearchMatchesTitleAndPreview() {
        let id = AccountID(issuer: "iss", subject: "1")
        let rows = [
            ConversationSummary(
                accountID: id, accountLabel: "Work", spaceName: "spaces/a",
                title: "#eng-standup", lastMessagePreview: "Alice: deploy",
                lastActivityAt: Date(), unreadCount: 0, isDM: false
            ),
            ConversationSummary(
                accountID: id, accountLabel: "Work", spaceName: "spaces/b",
                title: "Random", lastMessagePreview: "hello",
                lastActivityAt: Date(), unreadCount: 0, isDM: false
            ),
        ]
        XCTAssertEqual(InboxMerger.search(rows, query: "deploy").count, 1)
        XCTAssertEqual(InboxMerger.search(rows, query: "ENG").count, 1)
        XCTAssertEqual(InboxMerger.search(rows, query: "  ").count, 2)
    }

    func testCompositeIDUsesSpaceResourceNameNotTitle() {
        let id = AccountID(issuer: "iss", subject: "1")
        var row = ConversationSummary(
            accountID: id, accountLabel: "Work", spaceName: "spaces/AAA",
            title: "Old Name", lastMessagePreview: "", lastActivityAt: Date(),
            unreadCount: 0, isDM: false
        )
        let before = row.compositeID
        row.title = "Renamed"
        XCTAssertEqual(row.compositeID, before)
        XCTAssertEqual(row.compositeID, "iss|1:spaces/AAA")
    }
}
