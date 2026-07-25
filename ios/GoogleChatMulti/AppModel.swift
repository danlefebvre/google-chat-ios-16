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
    private let cache: any ConversationCaching
    private var api: ChatAPIClient?
    private var sync: InboxSyncService?
    /// Serializes cached-inbox loads so a later refresh cannot be overwritten by stale cache.
    private var cachedInboxTask: Task<Void, Never>?
    /// Coalesces concurrent refresh triggers (home appear + scene active).
    private var refreshTask: Task<Void, Never>?

    init(
        authStore: AccountAuthStore = KeychainAccountAuthStore(),
        cache: any ConversationCaching = GRDBConversationCache()
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
        let people = PeopleClient(tokens: tokens)
        api = client
        sync = InboxSyncService(api: client, cache: cache, people: people)
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
        if let refreshTask {
            await refreshTask.value
            return
        }
        let task = Task { @MainActor in
            await self.performRefresh()
        }
        refreshTask = task
        await task.value
        refreshTask = nil
    }

    private func performRefresh() async {
        // Wait for any in-flight cached load so stale results cannot overwrite refresh.
        await cachedInboxTask?.value
        guard let sync else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            conversations = try await sync.refreshAccounts(accounts)
        } catch {
            AppLog.inbox.error("refresh failed: \(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
            // Foreground fallback banner when sync/relay path is unhealthy.
            banner = "Could not refresh chats. Showing cached threads."
        }
    }

    func clearUnread(for compositeId: String) {
        guard let index = conversations.firstIndex(where: { $0.compositeId == compositeId }) else {
            return
        }
        conversations[index].unreadCount = 0
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
        guard
            let refresh = authStore.refreshToken(for: accountId),
            let access = authStore.accessToken(for: accountId)
        else {
            // Abort save so missing lookups cannot overwrite persisted tokens.
            return
        }
        authStore.save(account: account, refreshToken: refresh, accessToken: access)
        accounts = authStore.loadAccounts()
    }

    /// Removes the account from the relay first, then local credentials/cache.
    /// Pass `localOnly: true` only for an explicitly labeled local wipe.
    /// If relay teardown fails, still wipes the device and surfaces a warning.
    func removeAccount(_ accountId: AccountID, localOnly: Bool = false) async {
        var relayWarning: String?
        if !localOnly {
            if let client = RelayAdminClient.shared,
               let relayCredential = authStore.relayCredential(for: accountId),
               !relayCredential.isEmpty
            {
                do {
                    try await client.removeAccount(accountId, relayCredential: relayCredential)
                } catch {
                    AppLog.relay.error(
                        "teardown failed, continuing local wipe: \(error.localizedDescription, privacy: .public)"
                    )
                    relayWarning =
                        "Removed from this device; relay teardown failed — notifications may continue until the relay account is cleaned up."
                    errorMessage = error.localizedDescription
                }
            } else if RelayAdminClient.shared == nil {
                relayWarning = "Removed from this device; relay is not configured."
            } else {
                relayWarning =
                    "Removed from this device; missing relay credential so server-side teardown was skipped."
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
        if let relayWarning {
            banner = relayWarning
        }
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
