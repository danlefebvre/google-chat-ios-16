import XCTest
@testable import GoogleChatCore

final class InboxMergerTests: XCTestCase {
    private let work = AccountID(issuer: "https://accounts.google.com", subject: "work")
    private let home = AccountID(issuer: "https://accounts.google.com", subject: "home")

    func testMergeSortsByLastActivityDescending() {
        let older = Conversation(
            id: ConversationID(accountID: work, spaceName: "spaces/1"),
            title: "#eng-standup",
            lastMessagePreview: "Alice: deploy looks good",
            lastActivityAt: Date(timeIntervalSince1970: 100),
            unread: true,
            accountLabel: "Work",
            badgeColorHex: "#3366FF"
        )
        let newer = Conversation(
            id: ConversationID(accountID: home, spaceName: "spaces/2"),
            title: "Family",
            lastMessagePreview: "Mom: dinner at 7?",
            lastActivityAt: Date(timeIntervalSince1970: 200),
            unread: false,
            accountLabel: "Personal",
            badgeColorHex: "#2E8B57"
        )

        let merged = InboxMerger.merge(accountConversations: [
            work: [older],
            home: [newer],
        ])

        XCTAssertEqual(merged.map(\.id), [newer.id, older.id])
    }

    func testFilterByAccount() {
        let workConvo = Conversation(
            id: ConversationID(accountID: work, spaceName: "spaces/1"),
            title: "W",
            lastMessagePreview: "a",
            lastActivityAt: Date(timeIntervalSince1970: 2),
            unread: false,
            accountLabel: "Work",
            badgeColorHex: "#3366FF"
        )
        let homeConvo = Conversation(
            id: ConversationID(accountID: home, spaceName: "spaces/2"),
            title: "H",
            lastMessagePreview: "b",
            lastActivityAt: Date(timeIntervalSince1970: 1),
            unread: false,
            accountLabel: "Personal",
            badgeColorHex: "#2E8B57"
        )
        let all = [workConvo, homeConvo]
        let filtered = InboxMerger.filter(all, by: .account(work))
        XCTAssertEqual(filtered.map(\.id), [workConvo.id])
    }

    func testSearchMatchesTitleAndPreview() {
        let items = [
            Conversation(
                id: ConversationID(accountID: work, spaceName: "spaces/1"),
                title: "#eng-standup",
                lastMessagePreview: "deploy looks good",
                lastActivityAt: Date(timeIntervalSince1970: 2),
                unread: false,
                accountLabel: "Work",
                badgeColorHex: "#3366FF"
            ),
            Conversation(
                id: ConversationID(accountID: home, spaceName: "spaces/2"),
                title: "Family",
                lastMessagePreview: "dinner at 7?",
                lastActivityAt: Date(timeIntervalSince1970: 1),
                unread: false,
                accountLabel: "Personal",
                badgeColorHex: "#2E8B57"
            ),
        ]
        XCTAssertEqual(InboxMerger.search(items, query: "dinner").map(\.title), ["Family"])
        XCTAssertEqual(InboxMerger.search(items, query: "ENG").map(\.title), ["#eng-standup"])
    }
}
