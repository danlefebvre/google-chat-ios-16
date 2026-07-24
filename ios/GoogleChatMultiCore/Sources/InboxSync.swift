import Foundation

public protocol ConversationCaching: AnyObject, Sendable {
    /// Replace the authoritative snapshot for a refresh (stale rows must not linger).
    func replaceConversations(_ rows: [ConversationSummary]) async throws
    func loadConversations() async throws -> [ConversationSummary]
    func deleteConversations(accountId: AccountID) async throws
}

public actor InboxSyncService {
    private let api: ChatAPIClient
    private let cache: any ConversationCaching

    public init(api: ChatAPIClient, cache: any ConversationCaching) {
        self.api = api
        self.cache = cache
    }

    public func refreshAccounts(_ accounts: [LinkedAccount]) async throws -> [ConversationSummary] {
        var merged: [ConversationSummary] = []

        for account in accounts {
            let spaces = try await listAllSpaces(accountId: account.id)
            for space in spaces {
                let preview: String
                let activity: Date
                if let messages = try? await api.listMessages(
                    accountId: account.id,
                    spaceName: space.name,
                    pageSize: 1
                ), let latest = messages.messages.first {
                    let sender = latest.sender?.displayName ?? "Someone"
                    let text = latest.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    preview = text.isEmpty ? "\(sender): (attachment)" : "\(sender): \(text)"
                    activity = latest.createTime ?? space.lastActiveTime ?? .distantPast
                } else {
                    preview = ""
                    activity = space.lastActiveTime ?? .distantPast
                }

                merged.append(
                    ConversationSummary(
                        accountId: account.id,
                        accountLabel: account.label,
                        accountColorHex: account.colorHex,
                        spaceName: space.name,
                        title: space.isDirectMessage && space.resolvedTitle == "DM"
                            ? "DM"
                            : space.resolvedTitle,
                        lastMessagePreview: preview,
                        lastActivityAt: activity,
                        unreadCount: 0,
                        isDirectMessage: space.isDirectMessage
                    )
                )
            }
        }

        let sorted = InboxMerger.merge(merged)
        try await cache.replaceConversations(sorted)
        return sorted
    }

    public func cachedInbox() async throws -> [ConversationSummary] {
        InboxMerger.merge(try await cache.loadConversations())
    }

    public func purgeAccount(_ accountId: AccountID) async throws {
        try await cache.deleteConversations(accountId: accountId)
    }

    private func listAllSpaces(accountId: AccountID) async throws -> [ChatSpace] {
        var spaces: [ChatSpace] = []
        var pageToken: String? = nil
        repeat {
            let response = try await api.listSpaces(accountId: accountId, pageToken: pageToken)
            spaces.append(contentsOf: response.spaces)
            pageToken = response.nextPageToken
        } while pageToken != nil && !(pageToken?.isEmpty ?? true)
        return spaces
    }
}

/// In-memory cache used by tests and as a warm fallback before GRDB is wired.
public actor InMemoryConversationCache: ConversationCaching {
    private var rows: [ConversationSummary] = []

    public init() {}

    public func replaceConversations(_ rows: [ConversationSummary]) async throws {
        self.rows = rows
    }

    public func loadConversations() async throws -> [ConversationSummary] {
        rows
    }

    public func deleteConversations(accountId: AccountID) async throws {
        rows.removeAll { $0.accountId == accountId }
    }
}
