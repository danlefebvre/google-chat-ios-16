import XCTest
@testable import GoogleChatMultiCore

final class InboxMergerTests: XCTestCase {
    func testMergesAndSortsByLastActivityDescending() {
        let work = AccountID(issuer: "https://accounts.google.com", subject: "work")
        let home = AccountID(issuer: "https://accounts.google.com", subject: "home")

        let rows = InboxMerger.merge([
            ConversationSummary(
                accountId: home,
                accountLabel: "Personal",
                accountColorHex: "#2F6F4E",
                spaceName: "spaces/FAM",
                title: "Family",
                lastMessagePreview: "Mom: dinner at 7?",
                lastActivityAt: Date(timeIntervalSince1970: 1000),
                unreadCount: 1,
                isDirectMessage: false
            ),
            ConversationSummary(
                accountId: work,
                accountLabel: "Work",
                accountColorHex: "#C45C26",
                spaceName: "spaces/ENG",
                title: "#eng-standup",
                lastMessagePreview: "Alice: deploy looks good",
                lastActivityAt: Date(timeIntervalSince1970: 2000),
                unreadCount: 0,
                isDirectMessage: false
            ),
        ])

        XCTAssertEqual(rows.map(\.title), ["#eng-standup", "Family"])
        XCTAssertEqual(rows[0].compositeId, "https://accounts.google.com|work:spaces/ENG")
    }

    func testStableCompositeIdUsesSpaceResourceNameNotTitle() {
        let account = AccountID(issuer: "https://accounts.google.com", subject: "work")
        let before = ConversationSummary(
            accountId: account,
            accountLabel: "Work",
            accountColorHex: "#C45C26",
            spaceName: "spaces/ENG",
            title: "Old Name",
            lastMessagePreview: "hi",
            lastActivityAt: Date(),
            unreadCount: 0,
            isDirectMessage: false
        )
        let after = ConversationSummary(
            accountId: account,
            accountLabel: "Work",
            accountColorHex: "#C45C26",
            spaceName: "spaces/ENG",
            title: "New Name",
            lastMessagePreview: "hi",
            lastActivityAt: Date(),
            unreadCount: 0,
            isDirectMessage: false
        )
        XCTAssertEqual(before.compositeId, after.compositeId)
    }

    func testFilterByAccountLabel() {
        let work = AccountID(issuer: "https://accounts.google.com", subject: "work")
        let home = AccountID(issuer: "https://accounts.google.com", subject: "home")
        let rows = [
            ConversationSummary(
                accountId: work,
                accountLabel: "Work",
                accountColorHex: "#C45C26",
                spaceName: "spaces/A",
                title: "A",
                lastMessagePreview: "x",
                lastActivityAt: Date(timeIntervalSince1970: 2),
                unreadCount: 0,
                isDirectMessage: false
            ),
            ConversationSummary(
                accountId: home,
                accountLabel: "Personal",
                accountColorHex: "#2F6F4E",
                spaceName: "spaces/B",
                title: "B",
                lastMessagePreview: "y",
                lastActivityAt: Date(timeIntervalSince1970: 1),
                unreadCount: 0,
                isDirectMessage: false
            ),
        ]

        let filtered = InboxMerger.filter(rows, by: .accountLabel("Work"))
        XCTAssertEqual(filtered.map(\.title), ["A"])
    }

    func testSearchMatchesTitleAndPreview() {
        let account = AccountID(issuer: "https://accounts.google.com", subject: "work")
        let rows = [
            ConversationSummary(
                accountId: account,
                accountLabel: "Work",
                accountColorHex: "#C45C26",
                spaceName: "spaces/A",
                title: "#eng-standup",
                lastMessagePreview: "deploy looks good",
                lastActivityAt: Date(),
                unreadCount: 0,
                isDirectMessage: false
            ),
            ConversationSummary(
                accountId: account,
                accountLabel: "Work",
                accountColorHex: "#C45C26",
                spaceName: "spaces/B",
                title: "Random",
                lastMessagePreview: "hello",
                lastActivityAt: Date(),
                unreadCount: 0,
                isDirectMessage: false
            ),
        ]

        XCTAssertEqual(InboxMerger.search(rows, query: "deploy").map(\.title), ["#eng-standup"])
        XCTAssertEqual(InboxMerger.search(rows, query: "ENG").map(\.title), ["#eng-standup"])
    }

    func testExcludingHiddenKeepsRowUntilNewerActivity() {
        let account = AccountID(issuer: "https://accounts.google.com", subject: "work")
        let stamped = Date(timeIntervalSince1970: 1000)
        let hidden = ConversationSummary(
            accountId: account,
            accountLabel: "Work",
            accountColorHex: "#C45C26",
            spaceName: "spaces/A",
            title: "Hidden",
            lastMessagePreview: "old",
            lastActivityAt: stamped,
            unreadCount: 0,
            isDirectMessage: false
        )
        let visible = ConversationSummary(
            accountId: account,
            accountLabel: "Work",
            accountColorHex: "#C45C26",
            spaceName: "spaces/B",
            title: "Visible",
            lastMessagePreview: "hi",
            lastActivityAt: stamped,
            unreadCount: 0,
            isDirectMessage: false
        )
        let hiddenAt = [hidden.compositeId: stamped]

        XCTAssertEqual(
            HiddenConversationFilter.excludingHidden([hidden, visible], hiddenAt: hiddenAt).map(\.title),
            ["Visible"]
        )

        var revived = hidden
        revived.lastActivityAt = Date(timeIntervalSince1970: 1001)
        XCTAssertEqual(
            HiddenConversationFilter.excludingHidden([revived, visible], hiddenAt: hiddenAt).map(\.title),
            ["Hidden", "Visible"]
        )
    }

    func testPrunedHiddenDropsStampsAfterNewActivityOrMissingRow() {
        let account = AccountID(issuer: "https://accounts.google.com", subject: "work")
        let stamped = Date(timeIntervalSince1970: 1000)
        let stillHidden = ConversationSummary(
            accountId: account,
            accountLabel: "Work",
            accountColorHex: "#C45C26",
            spaceName: "spaces/A",
            title: "A",
            lastMessagePreview: "old",
            lastActivityAt: stamped,
            unreadCount: 0,
            isDirectMessage: false
        )
        let revived = ConversationSummary(
            accountId: account,
            accountLabel: "Work",
            accountColorHex: "#C45C26",
            spaceName: "spaces/B",
            title: "B",
            lastMessagePreview: "new",
            lastActivityAt: Date(timeIntervalSince1970: 2000),
            unreadCount: 1,
            isDirectMessage: false
        )
        let goneId = "\(account.rawValue):spaces/GONE"
        let hiddenAt = [
            stillHidden.compositeId: stamped,
            revived.compositeId: stamped,
            goneId: stamped,
        ]

        let pruned = HiddenConversationFilter.prunedHidden(hiddenAt, against: [stillHidden, revived])
        XCTAssertEqual(pruned.keys.sorted(), [stillHidden.compositeId])
    }
}
