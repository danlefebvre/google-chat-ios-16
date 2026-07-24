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

        let spyingAuth = OrderTrackingAuthStore(wrapping: auth) { order.append("device") }
        let coordinator = AccountRemovalCoordinator(relay: relay, authStore: spyingAuth, conversationStore: db)
        try await coordinator.remove(accountID: account)

        XCTAssertEqual(order, ["relay", "device"])
        let remainingAuth = try await auth.all()
        XCTAssertTrue(remainingAuth.isEmpty)
        let remainingRows = try await db.allConversations()
        XCTAssertTrue(remainingRows.isEmpty)
    }

    func testRemoveWipesCacheBeforeAuthDelete() async throws {
        let account = AccountID(issuer: "iss", subject: "home")
        let auth = InMemoryAuthStore()
        try await auth.upsert(AccountAuthorization(
            accountID: account, label: "Home", refreshToken: "rt",
            accessToken: "at", accessTokenExpiresAt: Date().addingTimeInterval(60)
        ))
        let db = InMemoryConversationStore()
        try await db.upsertConversations([
            ConversationSummary(
                accountID: account, accountLabel: "Home", spaceName: "spaces/BBB",
                title: "Fam", lastMessagePreview: "yo", lastActivityAt: Date(),
                unreadCount: 0, isDM: false
            ),
        ])

        var order: [String] = []
        MockURLProtocol.requestHandler = { _ in
            order.append("relay")
            return (HTTPURLResponse(url: URL(string: "https://relay.example")!, statusCode: 204, httpVersion: nil, headerFields: nil)!, Data())
        }
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let relay = RelayClient(baseURL: URL(string: "https://relay.example")!, session: URLSession(configuration: config))

        let wiping = OrderTrackingCacheStore(wrapping: db) { order.append("cache") }
        let spyingAuth = OrderTrackingAuthStore(wrapping: auth) { order.append("auth") }
        let coordinator = AccountRemovalCoordinator(relay: relay, authStore: spyingAuth, conversationStore: wiping)
        try await coordinator.remove(accountID: account)

        XCTAssertEqual(order, ["relay", "cache", "auth"])
    }
}

private struct OrderTrackingAuthStore: AuthStore {
    let wrapping: AuthStore
    let onRemove: @Sendable () -> Void

    func all() async throws -> [AccountAuthorization] { try await wrapping.all() }
    func authorization(for accountID: AccountID) async throws -> AccountAuthorization? {
        try await wrapping.authorization(for: accountID)
    }
    func upsert(_ auth: AccountAuthorization) async throws { try await wrapping.upsert(auth) }
    func remove(_ accountID: AccountID) async throws {
        onRemove()
        try await wrapping.remove(accountID)
    }
}

private struct OrderTrackingCacheStore: ConversationCacheWiping {
    let wrapping: ConversationCacheWiping
    let onWipe: @Sendable () -> Void

    func deleteConversations(for accountID: AccountID) async throws {
        try await wrapping.deleteConversations(for: accountID)
    }

    func deleteMessages(for accountID: AccountID) async throws {
        try await wrapping.deleteMessages(for: accountID)
    }

    func wipeAccountData(for accountID: AccountID) async throws {
        onWipe()
        try await wrapping.wipeAccountData(for: accountID)
    }
}
