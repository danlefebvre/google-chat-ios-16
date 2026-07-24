import Foundation

/// Removes an account using the locked teardown order: relay first, then device.
public struct AccountRemovalCoordinator: Sendable {
    public var relay: RelayClient
    public var authStore: AuthStore
    public var conversationStore: ConversationStore

    public init(relay: RelayClient, authStore: AuthStore, conversationStore: ConversationStore) {
        self.relay = relay
        self.authStore = authStore
        self.conversationStore = conversationStore
    }

    public func remove(accountID: AccountID) async throws {
        // (1–3) relay teardown (subscription → revoke token → ntfy binding) happens server-side on DELETE
        try await relay.removeAccount(accountID)
        // (4) wipe device-side binding/Keychain entries + local cache
        try await authStore.remove(accountID)
        if let wiping = conversationStore as? ConversationCacheWiping {
            try await wiping.deleteConversations(for: accountID)
            try await wiping.deleteMessages(for: accountID)
        }
    }
}

public protocol ConversationCacheWiping: Sendable {
    func deleteConversations(for accountID: AccountID) async throws
    func deleteMessages(for accountID: AccountID) async throws
}
