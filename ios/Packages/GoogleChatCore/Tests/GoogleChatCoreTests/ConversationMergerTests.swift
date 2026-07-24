import XCTest
@testable import GoogleChatCore

final class ConversationMergerTests: XCTestCase {
    func testMergesAndSortsByLastActivityDescending() {
        let work = AccountId(issuer: "https://accounts.google.com", subject: "work")
        let home = AccountId(issuer: "https://accounts.google.com", subject: "home")

        let rows = ConversationMerger.merge([
            ConversationSnapshot(
                accountId: work,
                accountLabel: "Work",
                accountColor: .work,
                spaceResourceName: "spaces/work1",
                title: "#eng-standup",
                lastMessagePreview: "deploy looks good",
                lastActivity: Date(timeIntervalSince1970: 100),
                unread: true
            ),
            ConversationSnapshot(
                accountId: home,
                accountLabel: "Personal",
                accountColor: .personal,
                spaceResourceName: "spaces/home1",
                title: "Family",
                lastMessagePreview: "dinner at 7?",
                lastActivity: Date(timeIntervalSince1970: 200),
                unread: false
            ),
        ])

        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[0].title, "Family")
        XCTAssertEqual(rows[1].title, "#eng-standup")
    }

    func testStableCompositeIdUsesSpaceResourceName() {
        let account = AccountId(issuer: "https://accounts.google.com", subject: "work")
        let row = ConversationSnapshot(
            accountId: account,
            accountLabel: "Work",
            accountColor: .work,
            spaceResourceName: "spaces/abc123",
            title: "Renamed Space",
            lastMessagePreview: "hi",
            lastActivity: Date(),
            unread: false
        )

        XCTAssertEqual(row.compositeId, "https://accounts.google.com|work:spaces/abc123")
    }

    func testFilterByAccountLabel() {
        let work = AccountId(issuer: "https://accounts.google.com", subject: "work")
        let home = AccountId(issuer: "https://accounts.google.com", subject: "home")
        let rows = [
            ConversationSnapshot(
                accountId: work,
                accountLabel: "Work",
                accountColor: .work,
                spaceResourceName: "spaces/w1",
                title: "Work chat",
                lastMessagePreview: "a",
                lastActivity: Date(),
                unread: false
            ),
            ConversationSnapshot(
                accountId: home,
                accountLabel: "Personal",
                accountColor: .personal,
                spaceResourceName: "spaces/h1",
                title: "Home chat",
                lastMessagePreview: "b",
                lastActivity: Date(),
                unread: false
            ),
        ]

        let filtered = ConversationMerger.filter(rows, accountLabel: "Work")
        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered[0].accountLabel, "Work")
    }

    func testSearchMatchesTitleAndPreview() {
        let account = AccountId(issuer: "https://accounts.google.com", subject: "work")
        let rows = [
            ConversationSnapshot(
                accountId: account,
                accountLabel: "Work",
                accountColor: .work,
                spaceResourceName: "spaces/w1",
                title: "#eng-standup",
                lastMessagePreview: "deploy looks good",
                lastActivity: Date(),
                unread: false
            ),
        ]

        XCTAssertEqual(ConversationMerger.search(rows, query: "deploy").count, 1)
        XCTAssertEqual(ConversationMerger.search(rows, query: "standup").count, 1)
        XCTAssertEqual(ConversationMerger.search(rows, query: "missing").count, 0)
    }
}
