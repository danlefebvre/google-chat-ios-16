import Foundation

public struct ConversationSummary: Hashable, Identifiable, Sendable {
    public var accountId: AccountID
    public var accountLabel: String
    public var accountColorHex: String
    public var spaceName: String
    public var title: String
    public var lastMessagePreview: String
    public var lastActivityAt: Date
    public var unreadCount: Int
    public var isDirectMessage: Bool

    public init(
        accountId: AccountID,
        accountLabel: String,
        accountColorHex: String,
        spaceName: String,
        title: String,
        lastMessagePreview: String,
        lastActivityAt: Date,
        unreadCount: Int,
        isDirectMessage: Bool
    ) {
        self.accountId = accountId
        self.accountLabel = accountLabel
        self.accountColorHex = accountColorHex
        self.spaceName = spaceName
        self.title = title
        self.lastMessagePreview = lastMessagePreview
        self.lastActivityAt = lastActivityAt
        self.unreadCount = unreadCount
        self.isDirectMessage = isDirectMessage
    }

    /// Stable composite id: `{accountId}:{spaceName}` (resource name, not title).
    public var compositeId: String {
        "\(accountId.rawValue):\(spaceName)"
    }

    public var id: String { compositeId }
}

public enum InboxFilter: Equatable, Sendable {
    case all
    case accountLabel(String)
    case accountId(AccountID)
}

public enum InboxMerger {
    public static func merge(_ rows: [ConversationSummary]) -> [ConversationSummary] {
        rows.sorted { lhs, rhs in
            if lhs.lastActivityAt != rhs.lastActivityAt {
                return lhs.lastActivityAt > rhs.lastActivityAt
            }
            return lhs.compositeId < rhs.compositeId
        }
    }

    public static func filter(
        _ rows: [ConversationSummary],
        by filter: InboxFilter
    ) -> [ConversationSummary] {
        switch filter {
        case .all:
            return rows
        case .accountLabel(let label):
            return rows.filter { $0.accountLabel.caseInsensitiveCompare(label) == .orderedSame }
        case .accountId(let accountId):
            return rows.filter { $0.accountId == accountId }
        }
    }

    public static func search(
        _ rows: [ConversationSummary],
        query: String
    ) -> [ConversationSummary] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return rows }
        return rows.filter {
            $0.title.localizedCaseInsensitiveContains(trimmed)
                || $0.lastMessagePreview.localizedCaseInsensitiveContains(trimmed)
                || $0.accountLabel.localizedCaseInsensitiveContains(trimmed)
        }
    }
}
