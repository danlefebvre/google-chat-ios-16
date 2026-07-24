import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import GoogleChatCore

final class AccountRemovalTests: XCTestCase {
    func testRemoveCallsRelayBeforeDeviceWipe() async throws {
        let account = AccountID(issuer: "iss", subject: "work")
        let auth = InMemoryAuthStore()
        try await auth.upsert(AccountAuthorization(
            accountID: account, label: "Work", refreshToken: "rt",
            accessToken: "at", accessTokenExpiresAt: Date().addingTimeInterval(60)
        ))
        let db = InMemoryConversationStore()
        try await db.upsertConversations([
            ConversationSummary(
                accountID: account, accountLabel: "Work", spaceName: "spaces/AAA",
                title: "Eng", lastMessagePreview: "hi", lastActivityAt: Date(),
                unreadCount: 0, isDM: false
            ),
        ])

        var order: [String] = []
        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.httpMethod, "DELETE")
            order.append("relay")
            return (HTTPURLResponse(url: request.url!, statusCode: 204, httpVersion: nil, headerFields: nil)!, Data())
        }
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let relay = RelayClient(baseURL: URL(string: "https://relay.example")!, session: URLSession(configuration: config))

        let coordinator = AccountRemovalCoordinator(relay: relay, authStore: auth, conversationStore: db)
        try await coordinator.remove(accountID: account)
        order.append("device")

        XCTAssertEqual(order, ["relay", "device"])
        let remainingAuth = try await auth.all()
        XCTAssertTrue(remainingAuth.isEmpty)
        let remainingRows = try await db.allConversations()
        XCTAssertTrue(remainingRows.isEmpty)
    }
}
