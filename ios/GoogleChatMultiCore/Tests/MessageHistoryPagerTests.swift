import XCTest
@testable import GoogleChatMultiCore

final class MessageHistoryPagerTests: XCTestCase {
    func testMergingOlderPageAppendsAndDeduplicates() {
        let existing = [
            ChatMessage(name: "spaces/A/messages/3", text: "newest"),
            ChatMessage(name: "spaces/A/messages/2", text: "mid"),
        ]
        let olderPage = [
            ChatMessage(name: "spaces/A/messages/2", text: "mid-dup"),
            ChatMessage(name: "spaces/A/messages/1", text: "oldest"),
        ]

        let merged = MessageHistoryPager.mergingOlderPage(existing, olderPage: olderPage)

        XCTAssertEqual(merged.map(\.name), [
            "spaces/A/messages/3",
            "spaces/A/messages/2",
            "spaces/A/messages/1",
        ])
        XCTAssertEqual(merged[1].text, "mid")
        XCTAssertEqual(merged[2].text, "oldest")
    }

    func testHasMorePages() {
        XCTAssertTrue(MessageHistoryPager.hasMorePages(nextPageToken: "abc"))
        XCTAssertFalse(MessageHistoryPager.hasMorePages(nextPageToken: nil))
        XCTAssertFalse(MessageHistoryPager.hasMorePages(nextPageToken: ""))
    }
}
