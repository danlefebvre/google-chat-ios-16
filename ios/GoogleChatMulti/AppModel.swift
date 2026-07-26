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
    private let defaults: UserDefaults
    /// compositeId → lastActivityAt at dismiss time; cleared when activity advances.
    @Published private(set) var hiddenConversationActivity: [String: Date] = [:]
    private var api: ChatAPIClient?
    private var sync: InboxSyncService?
    /// Serializes cached-inbox loads so a later refresh cannot be overwritten by stale cache.
    private var cachedInboxTask: Task<Void, Never>?
    /// Coalesces concurrent refresh triggers (home appear + scene active).
    private var refreshTask: Task<Void, Never>?

    private static let hiddenConversationsKey = "hiddenConversationActivity"

    init(
        authStore: AccountAuthStore = KeychainAccountAuthStore(),
        cache: any ConversationCaching = GRDBConversationCache(),
        defaults: UserDefaults = .standard
    ) {
        self.authStore = authStore
        self.cache = cache
        self.defaults = defaults
        hiddenConversationActivity = Self.loadHidden(from: defaults)
        bootstrap()
    }

    var visibleConversations: [ConversationSummary] {
        let filtered = InboxMerger.filter(conversations, by: filter)
        let searched = InboxMerger.search(filtered, query: searchQuery)
        return HiddenConversationFilter.excludingHidden(
            searched,
            hiddenAt: hiddenConversationActivity
        )
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
                applyConversations(rows)
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

    /// Ack unread pushes: Bark clears the icon on tap, but the relay counter
    /// must reset or the next message resumes at N+1.
    func acknowledgeNotifications() async {
        guard let client = RelayAdminClient.shared else { return }
        guard let credential = accounts
            .compactMap({ authStore.relayCredential(for: $0.id) })
            .first(where: { !$0.isEmpty })
        else { return }
        do {
            try await client.resetBadge(relayCredential: credential)
        } catch {
            AppLog.relay.error(
                "badge ack failed: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    private func performRefresh() async {
        // Wait for any in-flight cached load so stale results cannot overwrite refresh.
        await cachedInboxTask?.value
        guard let sync else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            applyConversations(try await sync.refreshAccounts(accounts))
            errorMessage = nil
        } catch {
            AppLog.inbox.error("refresh failed: \(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
            // Foreground fallback banner when sync/relay path is unhealthy.
            banner = "Could not refresh chats. Showing cached threads."
        }
    }

    /// Removes a conversation from the inbox until a newer message updates its activity.
    func hideFromInbox(_ conversation: ConversationSummary) {
        hiddenConversationActivity[conversation.compositeId] = conversation.lastActivityAt
        persistHidden()
        if selectedConversation?.compositeId == conversation.compositeId {
            selectedConversation = nil
        }
        path.removeAll { route in
            if case let .thread(id) = route { return id == conversation.compositeId }
            return false
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

    /// Persists a new label/color locally, updates inbox badges immediately, and
    /// syncs the label to the relay so push titles stay in sync. Color is local-only.
    func updateAccountDisplay(
        _ accountId: AccountID,
        label: String,
        colorHex: String
    ) async {
        let trimmedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedLabel.isEmpty else { return }
        guard var account = accounts.first(where: { $0.id == accountId }) else { return }
        let labelChanged = account.label != trimmedLabel
        let colorChanged = account.colorHex != colorHex
        guard labelChanged || colorChanged else { return }

        account.label = trimmedLabel
        account.colorHex = colorHex
        guard
            let refresh = authStore.refreshToken(for: accountId),
            let access = authStore.accessToken(for: accountId)
        else {
            banner = "Could not save account changes — missing credentials."
            return
        }
        authStore.save(account: account, refreshToken: refresh, accessToken: access)
        accounts = authStore.loadAccounts()
        // Inbox filter chips select by accountId, so renames keep the active account.

        let updatedRows = conversations.map { row -> ConversationSummary in
            guard row.accountId == accountId else { return row }
            var copy = row
            copy.accountLabel = trimmedLabel
            copy.accountColorHex = colorHex
            return copy
        }
        applyConversations(updatedRows)
        if var selected = selectedConversation, selected.accountId == accountId {
            selected.accountLabel = trimmedLabel
            selected.accountColorHex = colorHex
            selectedConversation = selected
        }
        do {
            try await cache.replaceConversations(updatedRows)
        } catch {
            AppLog.inbox.error(
                "cache update after account edit failed: \(error.localizedDescription, privacy: .public)"
            )
        }

        if labelChanged {
            await syncLabelToRelay(accountId: accountId, label: trimmedLabel)
        }
    }

    private func syncLabelToRelay(accountId: AccountID, label: String) async {
        guard let client = RelayAdminClient.shared else { return }

        if let credential = authStore.relayCredential(for: accountId), !credential.isEmpty {
            do {
                try await client.updateAccountLabel(
                    accountId,
                    label: label,
                    relayCredential: credential
                )
                return
            } catch {
                // Common after a wiped relay store: local credential no longer matches.
                AppLog.relay.error(
                    "label PATCH failed, trying re-register: \(error.localizedDescription, privacy: .public)"
                )
            }
        }

        // Re-register upserts the account with the current label (and a fresh credential).
        guard
            let account = accounts.first(where: { $0.id == accountId }),
            let refresh = authStore.refreshToken(for: accountId),
            !refresh.isEmpty
        else {
            banner =
                "Saved on this device; push label sync failed — notifications may still use the old name."
            return
        }
        do {
            let credential = try await client.registerAccount(
                account: account,
                refreshToken: refresh
            )
            authStore.saveRelayCredential(credential, for: accountId)
            markRelayRegistration(pending: false, for: accountId)
            AppLog.relay.info(
                "label sync recovered via re-register accountId=\(accountId.rawValue, privacy: .public)"
            )
        } catch {
            AppLog.relay.error(
                "label sync re-register failed: \(error.localizedDescription, privacy: .public)"
            )
            markRelayRegistration(pending: true, for: accountId)
            banner =
                "Saved on this device; push label sync failed — notifications may still use the old name."
        }
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
        applyConversations(conversations.filter { $0.accountId != accountId })
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

    private func applyConversations(_ rows: [ConversationSummary]) {
        conversations = rows
        let pruned = HiddenConversationFilter.prunedHidden(
            hiddenConversationActivity,
            against: rows
        )
        if pruned != hiddenConversationActivity {
            hiddenConversationActivity = pruned
            persistHidden()
        }
    }

    private func persistHidden() {
        let encoded = hiddenConversationActivity.mapValues { $0.timeIntervalSince1970 }
        defaults.set(encoded, forKey: Self.hiddenConversationsKey)
    }

    private static func loadHidden(from defaults: UserDefaults) -> [String: Date] {
        guard let raw = defaults.dictionary(forKey: hiddenConversationsKey) as? [String: Double]
        else { return [:] }
        return raw.mapValues { Date(timeIntervalSince1970: $0) }
    }
}

enum AppRoute: Hashable {
    case thread(String)
    case accounts
}
