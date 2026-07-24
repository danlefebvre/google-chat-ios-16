import Foundation

public struct ConversationSnapshot: Identifiable, Hashable, Sendable {
    public var id: String { compositeId }

    public let accountId: AccountId
    public let accountLabel: String
    public let accountColor: AccountBadgeColor
    public let spaceResourceName: String
    public let title: String
    public let lastMessagePreview: String
    public let lastActivity: Date
    public let unread: Bool

    public var compositeId: String {
        "\(accountId.rawValue):\(spaceResourceName)"
    }

    public init(
        accountId: AccountId,
        accountLabel: String,
        accountColor: AccountBadgeColor,
        spaceResourceName: String,
        title: String,
        lastMessagePreview: String,
        lastActivity: Date,
        unread: Bool
    ) {
        self.accountId = accountId
        self.accountLabel = accountLabel
        self.accountColor = accountColor
        self.spaceResourceName = spaceResourceName
        self.title = title
        self.lastMessagePreview = lastMessagePreview
        self.lastActivity = lastActivity
        self.unread = unread
    }
}

public enum ConversationMerger {
    public static func merge(_ snapshots: [ConversationSnapshot]) -> [ConversationSnapshot] {
        snapshots.sorted { $0.lastActivity > $1.lastActivity }
    }

    public static func filter(
        _ snapshots: [ConversationSnapshot],
        accountLabel: String?
    ) -> [ConversationSnapshot] {
        guard let accountLabel, !accountLabel.isEmpty else {
            return snapshots
        }
        return snapshots.filter { $0.accountLabel == accountLabel }
    }

    public static func search(
        _ snapshots: [ConversationSnapshot],
        query: String
    ) -> [ConversationSnapshot] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return snapshots
        }

        let needle = trimmed.lowercased()
        return snapshots.filter {
            $0.title.lowercased().contains(needle)
                || $0.lastMessagePreview.lowercased().contains(needle)
        }
    }
}
