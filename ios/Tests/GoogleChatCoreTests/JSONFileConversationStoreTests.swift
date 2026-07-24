import XCTest
@testable import GoogleChatCore

final class JSONFileConversationStoreTests: XCTestCase {
    func testPersistsAcrossReopen() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("chat-cache-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }

        let account = AccountID(issuer: "https://accounts.google.com", subject: "work")
        let convo = Conversation(
            id: ConversationID(accountID: account, spaceName: "spaces/AAA"),
            title: "#eng",
            lastMessagePreview: "hi",
            lastActivityAt: Date(timeIntervalSince1970: 100),
            unread: true,
            accountLabel: "Work",
            badgeColorHex: "#3366FF"
        )

        var store = try JSONFileConversationStore(fileURL: url)
        store.upsert([convo])

        let reopened = try JSONFileConversationStore(fileURL: url)
        XCTAssertEqual(reopened.all().map(\.title), ["#eng"])
    }
}
