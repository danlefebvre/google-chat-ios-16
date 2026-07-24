import Foundation

public struct ConversationSummary: Hashable, Sendable, Identifiable, Codable {
    public var accountId: AccountID
    public var spaceName: String
    public var title: String
    public var lastMessagePreview: String
    public var lastActivityAt: Date
    public var unreadCount: Int
    public var accountLabel: String
    public var badgeColorHex: String

    public init(
        accountId: AccountID,
        spaceName: String,
        title: String,
        lastMessagePreview: String,
        lastActivityAt: Date,
        unreadCount: Int,
        accountLabel: String,
        badgeColorHex: String
    ) {
        self.accountId = accountId
        self.spaceName = spaceName
        self.title = title
        self.lastMessagePreview = lastMessagePreview
        self.lastActivityAt = lastActivityAt
        self.unreadCount = unreadCount
        self.accountLabel = accountLabel
        self.badgeColorHex = badgeColorHex
    }

    /// Stable composite id: `{accountId}:{spaceName}` using immutable Chat resource name.
    public var compositeId: String {
        "\(accountId.rawValue):\(spaceName)"
    }

    public var id: String { compositeId }
}

public enum InboxFilter: Hashable, Sendable {
    case all
    case accountLabel(String)
    case account(AccountID)
}

public enum InboxMerger {
    public static func merge(
        conversations: [ConversationSummary],
        filter: InboxFilter
    ) -> [ConversationSummary] {
        let filtered: [ConversationSummary]
        switch filter {
        case .all:
            filtered = conversations
        case .accountLabel(let label):
            filtered = conversations.filter { $0.accountLabel == label }
        case .account(let id):
            filtered = conversations.filter { $0.accountId == id }
        }
        return filtered.sorted { $0.lastActivityAt > $1.lastActivityAt }
    }

    public static func search(
        conversations: [ConversationSummary],
        query: String
    ) -> [ConversationSummary] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return conversations }
        return conversations.filter {
            $0.title.localizedCaseInsensitiveContains(q)
                || $0.lastMessagePreview.localizedCaseInsensitiveContains(q)
        }
    }
}
