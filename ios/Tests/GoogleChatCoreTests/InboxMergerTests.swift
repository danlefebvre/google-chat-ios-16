import XCTest
@testable import GoogleChatCore

final class InboxMergerTests: XCTestCase {
    func testMergesAndSortsByLastActivityDescending() {
        let rows = [
            ConversationRow(
                accountKey: AccountKey(issuer: "i", subject: "a1"),
                accountLabel: "Work",
                accountColor: .work,
                spaceResourceName: "spaces/W1",
                title: "#eng",
                preview: "Alice: hi",
                lastActivityAt: Date(timeIntervalSince1970: 100),
                unread: true
            ),
            ConversationRow(
                accountKey: AccountKey(issuer: "i", subject: "a2"),
                accountLabel: "Personal",
                accountColor: .personal,
                spaceResourceName: "spaces/P1",
                title: "Family",
                preview: "Mom: dinner?",
                lastActivityAt: Date(timeIntervalSince1970: 200),
                unread: false
            ),
        ]

        let merged = InboxMerger.merge(rows)

        XCTAssertEqual(merged.count, 2)
        XCTAssertEqual(merged[0].compositeId, "i|a2:spaces/P1")
        XCTAssertEqual(merged[1].compositeId, "i|a1:spaces/W1")
    }

    func testFilterByAccountLabel() {
        let rows = [
            ConversationRow(
                accountKey: AccountKey(issuer: "i", subject: "a1"),
                accountLabel: "Work",
                accountColor: .work,
                spaceResourceName: "spaces/W1",
                title: "#eng",
                preview: "x",
                lastActivityAt: .now,
                unread: false
            ),
            ConversationRow(
                accountKey: AccountKey(issuer: "i", subject: "a2"),
                accountLabel: "Personal",
                accountColor: .personal,
                spaceResourceName: "spaces/P1",
                title: "Family",
                preview: "y",
                lastActivityAt: .now,
                unread: false
            ),
        ]

        let filtered = InboxMerger.filter(rows, accountLabel: "Work")
        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered[0].accountLabel, "Work")
    }
}
