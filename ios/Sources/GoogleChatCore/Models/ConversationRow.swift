import Foundation

public enum AccountColor: String, Codable, Sendable {
    case work
    case personal
    case other
}

public struct ConversationRow: Identifiable, Hashable, Sendable {
    public var id: String { compositeId }

    public let accountKey: AccountKey
    public let accountLabel: String
    public let accountColor: AccountColor
    public let spaceResourceName: String
    public let title: String
    public let preview: String
    public let lastActivityAt: Date
    public let unread: Bool

    public var compositeId: String {
        "\(accountKey.id):\(spaceResourceName)"
    }

    public init(
        accountKey: AccountKey,
        accountLabel: String,
        accountColor: AccountColor,
        spaceResourceName: String,
        title: String,
        preview: String,
        lastActivityAt: Date,
        unread: Bool
    ) {
        self.accountKey = accountKey
        self.accountLabel = accountLabel
        self.accountColor = accountColor
        self.spaceResourceName = spaceResourceName
        self.title = title
        self.preview = preview
        self.lastActivityAt = lastActivityAt
        self.unread = unread
    }
}
