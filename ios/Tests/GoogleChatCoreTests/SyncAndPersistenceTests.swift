import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import GoogleChatCore

final class SyncAndPersistenceTests: XCTestCase {
    func testUpsertSpacesIsConflictFreeByCompositeID() async throws {
        let db = InMemoryConversationStore()
        let account = AccountID(issuer: "iss", subject: "work")
        let first = ConversationSummary(
            accountID: account, accountLabel: "Work", spaceName: "spaces/AAA",
            title: "Old", lastMessagePreview: "a", lastActivityAt: Date(timeIntervalSince1970: 1),
            unreadCount: 1, isDM: false
        )
        let second = ConversationSummary(
            accountID: account, accountLabel: "Work", spaceName: "spaces/AAA",
            title: "New", lastMessagePreview: "b", lastActivityAt: Date(timeIntervalSince1970: 2),
            unreadCount: 0, isDM: false
        )
        try await db.upsertConversations([first])
        try await db.upsertConversations([second])
        let all = try await db.allConversations()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all[0].title, "New")
        XCTAssertEqual(all[0].unreadCount, 0)
    }

    func testSyncAccountFetchesPagesAndPersists() async throws {
        let account = AccountID(issuer: "iss", subject: "work", email: "w@ex.com")
        let auth = InMemoryAuthStore()
        try await auth.upsert(AccountAuthorization(
            accountID: account, label: "Work", refreshToken: "rt",
            accessToken: "tok", accessTokenExpiresAt: Date().addingTimeInterval(3600)
        ))

        var calls = 0
        MockURLProtocol.requestHandler = { request in
            calls += 1
            if calls == 1 {
                let json = """
                {"spaces":[{"name":"spaces/AAA","displayName":"#eng","spaceType":"SPACE"}],"nextPageToken":"p2"}
                """.data(using: .utf8)!
                return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, json)
            }
            let json = """
            {"spaces":[{"name":"spaces/BBB","displayName":"DM","spaceType":"DIRECT_MESSAGE"}]}
            """.data(using: .utf8)!
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, json)
        }

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        let client = ChatAPIClient(session: session, accessTokenProvider: { "tok" })
        let db = InMemoryConversationStore()
        let sync = AccountSync(client: client, store: db, accountLabel: "Work")

        try await sync.syncSpaces(accountID: account)
        let rows = try await db.allConversations()
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(Set(rows.map(\.spaceName)), Set(["spaces/AAA", "spaces/BBB"]))
    }

    func testMessageCachePaginationLimit() async throws {
        let db = InMemoryConversationStore()
        let account = AccountID(issuer: "iss", subject: "work")
        let space = "spaces/AAA"
        var messages: [ChatMessage] = []
        for i in 0..<5 {
            messages.append(ChatMessage(
                name: "spaces/AAA/messages/\(i)",
                spaceName: space,
                accountID: account,
                text: "m\(i)",
                senderDisplayName: "A",
                createTime: Date(timeIntervalSince1970: TimeInterval(i)),
                attachmentResourceNames: []
            ))
        }
        try await db.upsertMessages(messages)
        let page = try await db.messages(accountID: account, spaceName: space, limit: 2, before: nil)
        XCTAssertEqual(page.count, 2)
        XCTAssertEqual(page.map(\.text), ["m4", "m3"]) // newest first
    }
}
