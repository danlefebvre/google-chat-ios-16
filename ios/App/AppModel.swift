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

    private var conversationStore: JSONFileConversationStore
    private var accountStore: JSONFileAccountStore
    private let relayClient: RelayClient

    init(
        supportDirectory: URL? = nil,
        relayBaseURL: URL = URL(string: ProcessInfo.processInfo.environment["RELAY_URL"] ?? "http://127.0.0.1:8080")!
    ) {
        let dir = supportDirectory ?? Self.defaultSupportDirectory()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let accountsURL = dir.appendingPathComponent("accounts.json")
        let conversationsURL = dir.appendingPathComponent("conversations.json")
        self.accountStore = Self.loadAccountStore(at: accountsURL)
        self.conversationStore = Self.loadConversationStore(at: conversationsURL)
        self.relayClient = RelayClient(baseURL: relayBaseURL)
        self.accounts = accountStore.all()
        self.conversations = conversationStore.all()
    }

    var visibleConversations: [Conversation] {
        let filtered = InboxMerger.filter(conversations, by: filter)
        return InboxMerger.search(filtered, query: searchQuery)
    }

    func bootstrapPreviewData() {
        let workID = AccountID(issuer: "https://accounts.google.com", subject: "work")
        let homeID = AccountID(issuer: "https://accounts.google.com", subject: "home")
        let work = Account(id: workID, email: "work@example.com", label: "Work", badgeColorHex: "#3366FF")
        let home = Account(id: homeID, email: "me@example.com", label: "Personal", badgeColorHex: "#2E8B57")
        do {
            try accountStore.upsert(work)
            try accountStore.upsert(home)
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
            try conversationStore.upsert(sample)
            conversations = conversationStore.all()
        } catch {
            banner = "Could not save preview data"
        }
    }

    func addAccount(_ account: Account) {
        do {
            try accountStore.upsert(account)
            accounts = accountStore.all()
        } catch {
            banner = "Could not save account"
        }
    }

    /// Tears down relay subscriptions/tokens first, then clears local durable state.
    func removeAccount(_ id: AccountID) async {
        do {
            try await relayClient.teardownAccount(accountID: id)
        } catch {
            banner = "Could not remove account from relay"
            return
        }
        do {
            try accountStore.remove(id)
            try conversationStore.removeAll(for: id)
            accounts = accountStore.all()
            conversations = conversationStore.all()
            if selectedConversation?.id.accountID == id {
                selectedConversation = nil
            }
        } catch {
            banner = "Relay removed, but local cleanup failed"
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

    private static func defaultSupportDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("GoogleChatMulti", isDirectory: true)
    }

    private static func loadAccountStore(at url: URL) -> JSONFileAccountStore {
        if let store = try? JSONFileAccountStore(fileURL: url) {
            return store
        }
        try? FileManager.default.removeItem(at: url)
        if let store = try? JSONFileAccountStore(fileURL: url) {
            return store
        }
        let fallback = FileManager.default.temporaryDirectory
            .appendingPathComponent("gcm-accounts-\(UUID().uuidString).json")
        return try! JSONFileAccountStore(fileURL: fallback)
    }

    private static func loadConversationStore(at url: URL) -> JSONFileConversationStore {
        if let store = try? JSONFileConversationStore(fileURL: url) {
            return store
        }
        try? FileManager.default.removeItem(at: url)
        if let store = try? JSONFileConversationStore(fileURL: url) {
            return store
        }
        let fallback = FileManager.default.temporaryDirectory
            .appendingPathComponent("gcm-conversations-\(UUID().uuidString).json")
        return try! JSONFileConversationStore(fileURL: fallback)
    }
}
