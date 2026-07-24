import Foundation
import GoogleChatCore

@MainActor
public final class AppModel: ObservableObject {
    @Published public private(set) var conversations: [ConversationSnapshot] = []
    @Published public private(set) var accounts: [StoredAccount] = []
    @Published public var selectedFilter: String?
    @Published public var searchQuery = ""
    @Published public var errorMessage: String?
    @Published public var isLoading = false

    public let accountStore: AccountStore
    public let api: ChatAPIClient
    public let repository: ConversationRepository
    public let syncer: ConversationSyncer

    public init(accountStore: AccountStore) throws {
        self.accountStore = accountStore
        let dbQueue = try AppDatabase.makeQueue()
        self.repository = ConversationRepository(dbQueue: dbQueue)
        self.api = ChatAPIClient()
        self.syncer = ConversationSyncer(api: api, repository: repository)
        self.accounts = (try? accountStore.loadAll()) ?? []
        self.conversations = (try? repository.fetchAll()) ?? []
    }

    public var filteredConversations: [ConversationSnapshot] {
        let filtered = ConversationMerger.filter(conversations, accountLabel: selectedFilter)
        return ConversationMerger.search(filtered, query: searchQuery)
    }

    public func refresh() async {
        isLoading = true
        defer { isLoading = false }

        do {
            accounts = try accountStore.loadAll()
            var merged: [ConversationSnapshot] = []
            for account in accounts {
                let snapshots = try await syncer.syncAccount(account: account)
                merged.append(contentsOf: snapshots)
            }
            conversations = ConversationMerger.merge(merged)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func addAccount(_ account: StoredAccount) throws {
        try accountStore.save(account)
        accounts = try accountStore.loadAll()
    }

    public func removeAccount(_ account: StoredAccount) async throws {
        try accountStore.remove(accountId: account.accountId)
        accounts = try accountStore.loadAll()
        conversations.removeAll { $0.accountId == account.accountId }
        try repository.upsert(conversations)
    }

    public func openDeepLink(_ url: URL) throws -> DeepLink {
        try DeepLink(url: url)
    }

    public func sendMessage(
        account: StoredAccount,
        spaceResourceName: String,
        text: String
    ) async throws -> ChatMessage {
        try await api.createMessage(
            accessToken: account.accessToken,
            spaceName: spaceResourceName,
            text: text
        )
    }

    public func markRead(account: StoredAccount, spaceResourceName: String) async throws {
        try await api.markSpaceRead(
            accessToken: account.accessToken,
            spaceName: spaceResourceName
        )
    }
}
