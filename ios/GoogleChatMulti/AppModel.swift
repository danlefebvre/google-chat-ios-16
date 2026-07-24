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
        Task {
            do {
                conversations = try await sync?.cachedInbox() ?? []
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func refresh() async {
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

    func removeAccount(_ accountId: AccountID) async {
        // Relay teardown should happen before local wipe (plan order).
        await RelayAdminClient.shared?.removeAccount(accountId)
        authStore.remove(accountId: accountId)
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
