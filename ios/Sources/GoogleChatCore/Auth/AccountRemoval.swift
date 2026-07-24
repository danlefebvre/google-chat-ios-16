import Foundation

/// Removes an account using the locked teardown order: relay first, then device.
public struct AccountRemovalCoordinator: Sendable {
    public var relay: RelayClient
    public var authStore: AuthStore
    public var conversationStore: ConversationCacheWiping

    public init(relay: RelayClient, authStore: AuthStore, conversationStore: ConversationCacheWiping) {
        self.relay = relay
        self.authStore = authStore
        self.conversationStore = conversationStore
    }

    public func remove(accountID: AccountID) async throws {
        // (1–3) relay teardown (subscription → revoke token → ntfy binding) happens server-side on DELETE
        try await relay.removeAccount(accountID)
        // (4) wipe local cache before erasing auth so a failed wipe can be retried with credentials intact
        try await conversationStore.wipeAccountData(for: accountID)
        try await authStore.remove(accountID)
    }
}

public protocol ConversationCacheWiping: Sendable {
    func deleteConversations(for accountID: AccountID) async throws
    func deleteMessages(for accountID: AccountID) async throws
}

extension ConversationCacheWiping {
    public func wipeAccountData(for accountID: AccountID) async throws {
        try await deleteConversations(for: accountID)
        try await deleteMessages(for: accountID)
    }
}
