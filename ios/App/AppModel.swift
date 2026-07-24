import Foundation
import Combine
import GoogleChatCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

@MainActor
public final class AppModel: ObservableObject {
    @Published public var accounts: [StoredAuthorization] = []
    @Published public var conversations: [ConversationSummary] = []
    @Published public var filter: InboxFilter = .all
    @Published public var searchQuery: String = ""
    @Published public var selectedConversation: ConversationSummary?
    @Published public var threadMessages: [ChatMessage] = []
    @Published public var isSyncing = false
    @Published public var errorMessage: String?

    public let authStore: AuthStore
    public let conversationStore: ConversationStore
    public let chatClient: ChatClient
    public let banners: InAppBannerCenter
    public var relayBaseURL: URL?

    private let badgePalette = ["#C45C26", "#2F6F4E", "#1F4E79", "#7A3E5C"]

    public init(
        authStore: AuthStore,
        conversationStore: ConversationStore,
        chatClient: ChatClient = ChatClient(),
        banners: InAppBannerCenter = InAppBannerCenter(),
        relayBaseURL: URL? = nil
    ) {
        self.authStore = authStore
        self.conversationStore = conversationStore
        self.chatClient = chatClient
        self.banners = banners
        self.relayBaseURL = relayBaseURL
        refreshFromStores()
    }

    public var visibleConversations: [ConversationSummary] {
        let merged = InboxMerger.merge(conversations: conversations, filter: filter)
        return InboxMerger.search(conversations: merged, query: searchQuery)
    }

    public func refreshFromStores() {
        accounts = authStore.all()
        conversations = conversationStore.all()
    }

    public func nextBadgeColor() -> String {
        badgePalette[accounts.count % badgePalette.count]
    }

    public func upsertAuthorization(_ auth: StoredAuthorization) throws {
        try authStore.save(auth)
        refreshFromStores()
    }

    public func removeAccount(_ id: AccountID) async {
        if let relayBaseURL {
            let encoded = id.rawValue.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id.rawValue
            var req = URLRequest(url: relayBaseURL.appendingPathComponent("v1/accounts/\(encoded)"))
            req.httpMethod = "DELETE"
            _ = try? await URLSession.shared.data(for: req)
        }
        try? authStore.remove(id: id)
        for row in conversationStore.all() where row.accountId == id {
            conversationStore.remove(compositeId: row.compositeId)
        }
        if selectedConversation?.accountId == id {
            selectedConversation = nil
            threadMessages = []
        }
        refreshFromStores()
    }

    public func syncAll() async {
        isSyncing = true
        defer { isSyncing = false }
        let sync = SpaceSyncService(client: chatClient)
        for auth in authStore.all() {
            do {
                if auth.needsRefresh() {
                    errorMessage = "Re-auth required for \(auth.account.email)"
                    continue
                }
                try await sync.syncAccount(auth: auth, into: conversationStore)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
        refreshFromStores()
    }

    public func openConversation(_ conversation: ConversationSummary) async {
        selectedConversation = conversation
        guard let auth = accounts.first(where: { $0.account.id == conversation.accountId }) else {
            errorMessage = "Account missing for thread"
            return
        }
        do {
            let page = try await chatClient.listMessages(
                accessToken: auth.accessToken,
                spaceName: conversation.spaceName,
                pageSize: 40
            )
            threadMessages = page.messages.sorted {
                ($0.createTime ?? .distantPast) < ($1.createTime ?? .distantPast)
            }
            try await chatClient.markSpaceRead(
                accessToken: auth.accessToken,
                spaceName: conversation.spaceName
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func sendMessage(_ text: String) async {
        guard let conversation = selectedConversation,
              let auth = accounts.first(where: { $0.account.id == conversation.accountId })
        else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            let msg = try await chatClient.sendMessage(
                accessToken: auth.accessToken,
                spaceName: conversation.spaceName,
                text: trimmed
            )
            threadMessages.append(msg)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func react(to message: ChatMessage, emoji: String) async {
        guard let conversation = selectedConversation,
              let auth = accounts.first(where: { $0.account.id == conversation.accountId })
        else { return }
        do {
            try await chatClient.createReaction(
                accessToken: auth.accessToken,
                messageName: message.name,
                emojiUnicode: emoji
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func handleDeepLink(_ url: URL) async {
        do {
            let link = try DeepLinkParser.parse(url)
            guard case let .space(accountId, spaceName) = link else { return }
            if let row = conversations.first(where: { $0.accountId == accountId && $0.spaceName == spaceName }) {
                await openConversation(row)
            } else if let auth = accounts.first(where: { $0.account.id == accountId }) {
                let stub = ConversationSummary(
                    accountId: accountId,
                    spaceName: spaceName,
                    title: spaceName,
                    lastMessagePreview: "",
                    lastActivityAt: Date(),
                    unreadCount: 0,
                    accountLabel: auth.account.label,
                    badgeColorHex: auth.account.badgeColorHex
                )
                await openConversation(stub)
            }
        } catch {
            errorMessage = "Invalid deep link"
        }
    }

    public func presentFallbackBanner(
        from message: ChatMessage,
        account: Account,
        spaceTitle: String,
        spaceName: String
    ) {
        banners.present(InAppBanner(
            accountLabel: account.label,
            spaceTitle: spaceTitle,
            preview: "\(message.sender?.displayName ?? "Someone"): \(message.text ?? "")",
            accountId: account.id,
            spaceName: spaceName
        ))
    }

    public func uploadAttachment(filename: String, contentType: String, bytes: Data) async throws {
        guard let conversation = selectedConversation,
              let auth = accounts.first(where: { $0.account.id == conversation.accountId })
        else { return }
        let msg = try await chatClient.uploadMedia(
            accessToken: auth.accessToken,
            spaceName: conversation.spaceName,
            filename: filename,
            contentType: contentType,
            bytes: bytes
        )
        threadMessages.append(msg)
    }
}

@MainActor
final class BannerBridge: ObservableObject {
    @Published var current: InAppBanner?
    private let center: InAppBannerCenter

    init(center: InAppBannerCenter) {
        self.center = center
        self.current = center.current
        center.onChange = { [weak self] banner in
            Task { @MainActor in
                self?.current = banner
            }
        }
    }

    func dismiss() {
        center.dismiss()
    }
}
