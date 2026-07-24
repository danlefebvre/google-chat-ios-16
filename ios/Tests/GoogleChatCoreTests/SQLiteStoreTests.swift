import XCTest
@testable import GoogleChatCore

final class SQLiteStoreTests: XCTestCase {
    func testRoundTripConversationAndMessages() async throws {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("gcm-\(UUID().uuidString).sqlite")
            .path
        defer { try? FileManager.default.removeItem(atPath: path) }

        let store = try SQLiteConversationStore(path: path)
        let account = AccountID(issuer: "iss", subject: "work")
        try await store.upsertConversations([
            ConversationSummary(
                accountID: account, accountLabel: "Work", spaceName: "spaces/AAA",
                title: "#eng", lastMessagePreview: "hi", lastActivityAt: Date(timeIntervalSince1970: 10),
                unreadCount: 2, isDM: false
            ),
        ])
        try await store.upsertMessages([
            ChatMessage(
                name: "spaces/AAA/messages/1",
                spaceName: "spaces/AAA",
                accountID: account,
                text: "hello",
                senderDisplayName: "Alice",
                createTime: Date(timeIntervalSince1970: 11),
                attachmentResourceNames: ["media/1"]
            ),
        ])

        let rows = try await store.allConversations()
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].title, "#eng")

        let messages = try await store.messages(accountID: account, spaceName: "spaces/AAA", limit: 10, before: nil)
        XCTAssertEqual(messages.count, 1)
        XCTAssertEqual(messages[0].attachmentResourceNames, ["media/1"])

        try await store.deleteConversations(for: account)
        try await store.deleteMessages(for: account)
        let remainingRows = try await store.allConversations()
        XCTAssertTrue(remainingRows.isEmpty)
        let remainingMessages = try await store.messages(accountID: account, spaceName: "spaces/AAA", limit: 10, before: nil)
        XCTAssertTrue(remainingMessages.isEmpty)
    }
}
