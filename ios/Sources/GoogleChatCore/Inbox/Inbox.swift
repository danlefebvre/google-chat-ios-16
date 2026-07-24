import Foundation

public struct ConversationSummary: Sendable, Equatable, Identifiable {
    public var accountID: AccountID
    public var accountLabel: String
    public var spaceName: String
    public var title: String
    public var lastMessagePreview: String
    public var lastActivityAt: Date
    public var unreadCount: Int
    public var isDM: Bool

    public init(
        accountID: AccountID,
        accountLabel: String,
        spaceName: String,
        title: String,
        lastMessagePreview: String,
        lastActivityAt: Date,
        unreadCount: Int,
        isDM: Bool
    ) {
        self.accountID = accountID
        self.accountLabel = accountLabel
        self.spaceName = spaceName
        self.title = title
        self.lastMessagePreview = lastMessagePreview
        self.lastActivityAt = lastActivityAt
        self.unreadCount = unreadCount
        self.isDM = isDM
    }

    public var compositeID: String {
        "\(accountID.rawValue):\(spaceName)"
    }

    public var id: String { compositeID }
}

public enum InboxMerger {
    public static func merge(_ rows: [ConversationSummary]) -> [ConversationSummary] {
        rows.sorted { $0.lastActivityAt > $1.lastActivityAt }
    }

    public static func filter(_ rows: [ConversationSummary], accountID: AccountID?) -> [ConversationSummary] {
        guard let accountID else { return rows }
        return rows.filter { $0.accountID == accountID }
    }

    public static func search(_ rows: [ConversationSummary], query: String) -> [ConversationSummary] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return rows }
        return rows.filter {
            $0.title.localizedCaseInsensitiveContains(q)
                || $0.lastMessagePreview.localizedCaseInsensitiveContains(q)
                || $0.accountLabel.localizedCaseInsensitiveContains(q)
        }
    }
}
