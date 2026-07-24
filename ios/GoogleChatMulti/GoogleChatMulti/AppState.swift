import Foundation
import GoogleChatCore

@MainActor
final class AppState: ObservableObject {
    @Published var accounts: [AccountProfile] = []
    @Published var conversations: [ConversationItem] = []
    @Published var inboxFilter: InboxFilter = .all
    @Published var searchQuery: String = ""
    @Published var selectedConversation: ConversationItem?
    @Published var pendingDeepLink: DeepLinkRoute?

    private var rowsByAccount: [AccountId: [ConversationItem]] = [:]
    private let inboxMerger = InboxMerger()
    private let tokenStore = KeychainTokenStore()
    let chatClient = ChatAPIClient()

    func setRows(_ rows: [ConversationItem], for accountId: AccountId) {
        rowsByAccount[accountId] = rows
        refreshInbox()
    }

    func refreshInbox() {
        conversations = inboxMerger.merge(
            rowsByAccount: rowsByAccount,
            filter: inboxFilter,
            searchQuery: searchQuery
        )
    }

    func handleDeepLink(_ url: URL) {
        pendingDeepLink = DeepLinkRoute.parse(url: url)
        if case .space(let accountId, let spaceName)? = pendingDeepLink {
            selectedConversation = conversations.first {
                $0.accountId == accountId && $0.spaceName == spaceName
            }
        }
    }

    func signOut(accountId: AccountId) async {
        accounts.removeAll { $0.accountId == accountId }
        rowsByAccount.removeValue(forKey: accountId)
        try? tokenStore.deleteTokens(for: accountId)
        refreshInbox()
    }
}
