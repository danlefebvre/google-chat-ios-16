import Foundation
import GoogleChatCore

@MainActor
final class AppState: ObservableObject {
    @Published var accounts: [AccountProfile] = []
    @Published var conversations: [ConversationSummary] = []
    @Published var accountFilter: AccountFilter = .all
    @Published var searchQuery: String = ""
    @Published var pendingDeepLinkConversationId: ConversationId?
    @Published var navigationPath: [ConversationId] = []

    private let merger = InboxMerger()
    private let upserter = ConversationUpserter()

    var filteredConversations: [ConversationSummary] {
        let filtered = merger.filter(conversations, by: accountFilter)
        let searched = merger.search(filtered, query: searchQuery)
        return merger.merge(searched)
    }

    func addAccount(_ profile: AccountProfile) {
        guard !accounts.contains(where: { $0.accountId == profile.accountId }) else { return }
        accounts.append(profile)
    }

    func removeAccount(_ accountId: AccountId) {
        accounts.removeAll { $0.accountId == accountId }
        conversations.removeAll { $0.conversationId.accountId == accountId }
        if case .account(let filteredId) = accountFilter, filteredId == accountId {
            accountFilter = .all
        }
        navigationPath.removeAll { $0.accountId == accountId }
    }

    func upsertConversations(_ incoming: [ConversationSummary]) {
        conversations = merger.merge(upserter.upsertMany(existing: conversations, incoming: incoming))
    }

    func handleDeepLink(_ url: URL) {
        guard url.scheme == "gchatmulti", url.host == "space" else { return }
        let rawPath = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let raw = rawPath.removingPercentEncoding ?? rawPath
        guard let conversationId = ConversationId(rawValue: raw) else { return }
        pendingDeepLinkConversationId = conversationId
    }

    func openDeepLinkConversation(_ conversationId: ConversationId) {
        if case .account(let filteredId) = accountFilter, filteredId != conversationId.accountId {
            accountFilter = .all
        }
        searchQuery = ""
        if navigationPath.last != conversationId {
            navigationPath.append(conversationId)
        }
        pendingDeepLinkConversationId = nil
    }
}
