import Foundation
import SwiftUI
import GoogleChatMultiCore

@MainActor
final class AppModel: ObservableObject {
    @Published var accounts: [LinkedAccount] = []
    @Published var conversations: [ConversationSummary] = []
    @Published var filter: InboxFilter = .all
    @Published var searchQuery: String = ""
    @Published var selectedConversation: ConversationSummary?
    @Published var path: [AppRoute] = []
    @Published var banner: String?
    @Published var isRefreshing = false
    @Published var errorMessage: String?

    let authStore: AccountAuthStore
    private let cache: GRDBConversationCache
    private var api: ChatAPIClient?
    private var sync: InboxSyncService?
    /// Serializes cached-inbox loads so a later refresh cannot be overwritten by stale cache.
    private var cachedInboxTask: Task<Void, Never>?

    init(
        authStore: AccountAuthStore = KeychainAccountAuthStore(),
        cache: GRDBConversationCache = GRDBConversationCache()
    ) {
        self.authStore = authStore
        self.cache = cache
        bootstrap()
    }

    var visibleConversations: [ConversationSummary] {
        let filtered = InboxMerger.filter(conversations, by: filter)
        return InboxMerger.search(filtered, query: searchQuery)
    }

    func bootstrap() {
        accounts = authStore.loadAccounts()
        let tokens = authStore.asTokenProvider()
        let client = ChatAPIClient(tokens: tokens)
        api = client
        sync = InboxSyncService(api: client, cache: cache)
        cachedInboxTask?.cancel()
        let syncService = sync
        cachedInboxTask = Task {
            do {
                let rows = try await syncService?.cachedInbox() ?? []
                try Task.checkCancellation()
                conversations = rows
            } catch is CancellationError {
                // Superseded by a newer bootstrap/refresh sequence.
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func refresh() async {
        // Wait for any in-flight cached load so stale results cannot overwrite refresh.
        await cachedInboxTask?.value
        guard let sync else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            conversations = try await sync.refreshAccounts(accounts)
        } catch {
            errorMessage = error.localizedDescription
            // Foreground fallback banner when sync/relay path is unhealthy.
            banner = "Could not refresh chats. Showing cached threads."
        }
    }

    func addAccount(_ account: LinkedAccount, refreshToken: String, accessToken: String) {
        authStore.save(account: account, refreshToken: refreshToken, accessToken: accessToken)
        accounts = authStore.loadAccounts()
        bootstrap()
        Task { await refresh() }
    }

    func markRelayRegistration(pending: Bool, for accountId: AccountID) {
        guard var account = accounts.first(where: { $0.id == accountId }) else { return }
        account.relayRegistrationPending = pending
        let refresh = authStore.refreshToken(for: accountId) ?? ""
        let access = authStore.accessToken(for: accountId) ?? ""
        authStore.save(account: account, refreshToken: refresh, accessToken: access)
        accounts = authStore.loadAccounts()
    }

    /// Removes the account from the relay first, then local credentials/cache.
    /// Pass `localOnly: true` only for an explicitly labeled local wipe.
    func removeAccount(_ accountId: AccountID, localOnly: Bool = false) async {
        if !localOnly {
            guard let client = RelayAdminClient.shared else {
                banner = "Relay is not configured. Choose local-only removal to wipe this device."
                errorMessage = "Relay not configured"
                return
            }
            guard let refresh = authStore.refreshToken(for: accountId), !refresh.isEmpty else {
                banner = "Missing refresh token; cannot tear down relay registration."
                errorMessage = "Missing refresh token"
                return
            }
            do {
                try await client.removeAccount(accountId, refreshToken: refresh)
            } catch {
                banner = "Relay teardown failed; local account kept. Retry remove later."
                errorMessage = error.localizedDescription
                return
            }
        }

        authStore.remove(accountId: accountId)
        do {
            try await sync?.purgeAccount(accountId)
        } catch {
            // Best-effort cache purge; local credentials already removed.
            errorMessage = error.localizedDescription
        }
        accounts = authStore.loadAccounts()
        conversations = conversations.filter { $0.accountId != accountId }
    }

    func open(_ conversation: ConversationSummary) {
        selectedConversation = conversation
        path.append(.thread(conversation.compositeId))
    }

    func handleDeepLink(_ url: URL) {
        do {
            let link = try DeepLinkParser.parse(url)
            switch link {
            case let .space(accountId, spaceName):
                if let match = conversations.first(where: {
                    $0.accountId == accountId && $0.spaceName == spaceName
                }) {
                    open(match)
                } else {
                    path.append(.thread("\(accountId.rawValue):\(spaceName)"))
                }
            }
        } catch {
            banner = "Could not open link."
        }
    }
}

enum AppRoute: Hashable {
    case thread(String)
    case accounts
}
