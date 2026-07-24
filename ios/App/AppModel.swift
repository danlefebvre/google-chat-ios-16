import Foundation
import SwiftUI
import GoogleChatCore

@MainActor
final class AppModel: ObservableObject {
    @Published var accounts: [Account] = []
    @Published var conversations: [Conversation] = []
    @Published var filter: InboxFilter = .all
    @Published var searchQuery: String = ""
    @Published var selectedConversation: Conversation?
    @Published var banner: String?

    private var conversationStore = InMemoryConversationStore()
    private var accountStore = InMemoryAccountStore()

    var visibleConversations: [Conversation] {
        let filtered = InboxMerger.filter(conversations, by: filter)
        return InboxMerger.search(filtered, query: searchQuery)
    }

    func bootstrapPreviewData() {
        let workID = AccountID(issuer: "https://accounts.google.com", subject: "work")
        let homeID = AccountID(issuer: "https://accounts.google.com", subject: "home")
        let work = Account(id: workID, email: "work@example.com", label: "Work", badgeColorHex: "#3366FF")
        let home = Account(id: homeID, email: "me@example.com", label: "Personal", badgeColorHex: "#2E8B57")
        accountStore.upsert(work)
        accountStore.upsert(home)
        accounts = accountStore.all()

        let sample = [
            Conversation(
                id: ConversationID(accountID: workID, spaceName: "spaces/eng"),
                title: "#eng-standup",
                lastMessagePreview: "Alice: deploy looks good",
                lastActivityAt: Date().addingTimeInterval(-120),
                unread: true,
                accountLabel: "Work",
                badgeColorHex: "#3366FF"
            ),
            Conversation(
                id: ConversationID(accountID: homeID, spaceName: "spaces/family"),
                title: "Family",
                lastMessagePreview: "Mom: dinner at 7?",
                lastActivityAt: Date().addingTimeInterval(-660),
                unread: false,
                accountLabel: "Personal",
                badgeColorHex: "#2E8B57"
            ),
            Conversation(
                id: ConversationID(accountID: workID, spaceName: "spaces/sam"),
                title: "DM · Sam",
                lastMessagePreview: "You: sent the doc",
                lastActivityAt: Date().addingTimeInterval(-3600),
                unread: false,
                accountLabel: "Work",
                badgeColorHex: "#3366FF"
            ),
        ]
        conversationStore.upsert(sample)
        conversations = conversationStore.all()
    }

    func addAccount(_ account: Account) {
        accountStore.upsert(account)
        accounts = accountStore.all()
    }

    func removeAccount(_ id: AccountID) {
        accountStore.remove(id)
        conversationStore.removeAll(for: id)
        accounts = accountStore.all()
        conversations = conversationStore.all()
        if selectedConversation?.id.accountID == id {
            selectedConversation = nil
        }
    }

    func handle(url: URL) {
        do {
            let link = try DeepLink.parse(url)
            if case let .space(accountID, spaceName) = link {
                let id = ConversationID(accountID: accountID, spaceName: spaceName)
                selectedConversation = conversations.first(where: { $0.id == id })
            }
        } catch {
            banner = "Could not open link"
        }
    }

    func showFallbackBanner(_ text: String) {
        banner = text
    }
}
