import Foundation

public protocol ConversationCaching: AnyObject, Sendable {
    func upsertConversations(_ rows: [ConversationSummary]) async throws
    func loadConversations() async throws -> [ConversationSummary]
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
            let response = try await api.listSpaces(accountId: account.id)
            for space in response.spaces {
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
        try await cache.upsertConversations(sorted)
        return sorted
    }

    public func cachedInbox() async throws -> [ConversationSummary] {
        InboxMerger.merge(try await cache.loadConversations())
    }
}

/// In-memory cache used by tests and as a warm fallback before GRDB is wired.
public actor InMemoryConversationCache: ConversationCaching {
    private var rows: [ConversationSummary] = []

    public init() {}

    public func upsertConversations(_ rows: [ConversationSummary]) async throws {
        var map = Dictionary(uniqueKeysWithValues: self.rows.map { ($0.compositeId, $0) })
        for row in rows {
            map[row.compositeId] = row
        }
        self.rows = Array(map.values)
    }

    public func loadConversations() async throws -> [ConversationSummary] {
        rows
    }
}
