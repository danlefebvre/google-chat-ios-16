import Foundation

/// Immutable account key: `{issuer}|{sub}`. Email is display-only.
public struct AccountId: Hashable, Codable, Sendable {
    public let issuer: String
    public let sub: String

    public init(issuer: String, sub: String) {
        self.issuer = issuer
        self.sub = sub
    }

    public var rawValue: String {
        "\(issuer)|\(sub)"
    }

    public init?(rawValue: String) {
        let parts = rawValue.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2 else { return nil }
        self.issuer = String(parts[0])
        self.sub = String(parts[1])
    }
}

public struct AccountProfile: Identifiable, Codable, Sendable, Equatable {
    public var id: AccountId { accountId }
    public let accountId: AccountId
    public let email: String
    public let label: String
    public let badgeColorHex: String

    public init(accountId: AccountId, email: String, label: String, badgeColorHex: String) {
        self.accountId = accountId
        self.email = email
        self.label = label
        self.badgeColorHex = badgeColorHex
    }
}

/// Composite conversation id: `{accountId}:{spaceName}` where spaceName is `spaces/{id}`.
public struct ConversationId: Hashable, Codable, Sendable {
    public let accountId: AccountId
    /// Immutable Chat API resource name, e.g. `spaces/AAA`.
    public let spaceName: String

    public init(accountId: AccountId, spaceName: String) {
        self.accountId = accountId
        self.spaceName = spaceName
    }

    public var rawValue: String {
        "\(accountId.rawValue):\(spaceName)"
    }

    public init?(rawValue: String) {
        guard let colon = rawValue.firstIndex(of: ":") else { return nil }
        let accountPart = String(rawValue[..<colon])
        let spacePart = String(rawValue[rawValue.index(after: colon)...])
        guard let accountId = AccountId(rawValue: accountPart) else { return nil }
        self.accountId = accountId
        self.spaceName = spacePart
    }
}

public struct ConversationSummary: Identifiable, Codable, Sendable, Equatable {
    public var id: ConversationId { conversationId }
    public let conversationId: ConversationId
    public let accountLabel: String
    public let title: String
    public let lastMessagePreview: String
    public let lastActivity: Date
    public let unread: Bool

    public init(
        conversationId: ConversationId,
        accountLabel: String,
        title: String,
        lastMessagePreview: String,
        lastActivity: Date,
        unread: Bool
    ) {
        self.conversationId = conversationId
        self.accountLabel = accountLabel
        self.title = title
        self.lastMessagePreview = lastMessagePreview
        self.lastActivity = lastActivity
        self.unread = unread
    }
}

public struct ChatMessage: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public let spaceName: String
    public let senderName: String
    public let text: String
    public let createTime: Date
    public let isFromCurrentUser: Bool

    public init(
        id: String,
        spaceName: String,
        senderName: String,
        text: String,
        createTime: Date,
        isFromCurrentUser: Bool
    ) {
        self.id = id
        self.spaceName = spaceName
        self.senderName = senderName
        self.text = text
        self.createTime = createTime
        self.isFromCurrentUser = isFromCurrentUser
    }
}

public enum AccountFilter: Equatable, Sendable {
    case all
    case account(AccountId)
}
