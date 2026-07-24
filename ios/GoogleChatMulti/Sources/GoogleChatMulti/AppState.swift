import Foundation
import GoogleChatCore

@MainActor
final class AppState: ObservableObject {
    @Published var accounts: [AccountProfile] = []
    @Published var conversations: [ConversationSummary] = []
    @Published var accountFilter: AccountFilter = .all
    @Published var searchQuery: String = ""
    @Published var pendingDeepLinkConversationId: ConversationId?

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
    }

    func upsertConversations(_ incoming: [ConversationSummary]) {
        conversations = merger.merge(upserter.upsertMany(existing: conversations, incoming: incoming))
    }

    func handleDeepLink(_ url: URL) {
        guard url.scheme == "gchatmulti",
              url.host == "space",
              let raw = url.pathComponents.dropFirst().first,
              let conversationId = ConversationId(rawValue: raw)
        else { return }
        pendingDeepLinkConversationId = conversationId
    }
}
