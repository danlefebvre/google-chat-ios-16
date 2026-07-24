import Foundation
import GoogleChatCore

@MainActor
final class AppModel: ObservableObject {
    @Published var conversations: [ConversationRow] = []
    @Published var selectedConversation: ConversationRow?
    @Published var accounts: [StoredAccount] = []
    @Published var filterLabel: String?
    @Published var searchQuery = ""
    @Published var errorMessage: String?

    private let accountStore: AccountStore
    private let api = ChatAPIClient()
    private let syncService: ConversationSyncService
    private var cache: ConversationCache?

    init(accountStore: AccountStore = InMemoryAccountStore()) {
        self.accountStore = accountStore
        self.syncService = ConversationSyncService(api: api, accountStore: accountStore)
        bootstrapCache()
    }

    var filteredConversations: [ConversationRow] {
        let filtered = InboxMerger.filter(conversations, accountLabel: filterLabel)
        return InboxMerger.search(filtered, query: searchQuery)
    }

    func refresh() async {
        do {
            accounts = try accountStore.allAccounts()
            let rows = try await syncService.syncAllConversations()
            conversations = rows
            try cache?.upsert(rows)
        } catch {
            errorMessage = error.localizedDescription
            if let cached = try? cache?.fetchAll(), !cached.isEmpty {
                conversations = cached
            }
        }
    }

    func addDemoAccount(label: String, color: AccountColor) {
        let key = AccountKey(issuer: "https://accounts.google.com", subject: UUID().uuidString)
        let account = StoredAccount(
            key: key,
            label: label,
            color: color,
            accessToken: "demo",
            refreshToken: "demo",
            expiresAt: Date().addingTimeInterval(3600)
        )
        try? accountStore.save(account)
        Task { await refresh() }
    }

    func removeAccount(_ account: StoredAccount) async {
        try? accountStore.remove(accountId: account.id)
        await refresh()
    }

    func sendMessage(text: String, in conversation: ConversationRow) async {
        guard let account = try? accountStore.account(for: conversation.accountKey.id) else { return }
        do {
            _ = try await api.sendMessage(
                spaceResourceName: conversation.spaceResourceName,
                text: text,
                accessToken: account.accessToken
            )
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func handleDeepLink(_ url: URL) {
        guard case .space(let resourceName) = try? DeepLinkParser.parse(url) else { return }
        selectedConversation = conversations.first { $0.spaceResourceName == resourceName }
    }

    private func bootstrapCache() {
        let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("conversations.sqlite")
        cache = try? ConversationCache(databaseURL: url)
        conversations = (try? cache?.fetchAll()) ?? []
    }
}
