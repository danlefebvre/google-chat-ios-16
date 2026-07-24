import Foundation

/// Stable composite id: `{accountId.key}:{spaceName}` (space resource name, not title).
public struct ConversationID: Hashable, Sendable, Codable, RawRepresentable {
    public let accountID: AccountID
    public let spaceName: String

    public init(accountID: AccountID, spaceName: String) {
        self.accountID = accountID
        self.spaceName = spaceName
    }

    public var rawValue: String { "\(accountID.key):\(spaceName)" }

    public init?(rawValue: String) {
        // Format: `{issuer}|{subject}:{spaceName}` — issuer URLs contain ':',
        // so split on the first ':' that appears after '|'.
        guard let pipe = rawValue.firstIndex(of: "|") else { return nil }
        guard let colon = rawValue[pipe...].firstIndex(of: ":") else { return nil }
        let key = String(rawValue[..<colon])
        let space = String(rawValue[rawValue.index(after: colon)...])
        guard let accountID = try? AccountID(key: key), !space.isEmpty else { return nil }
        self.accountID = accountID
        self.spaceName = space
    }
}

public struct Conversation: Hashable, Sendable, Identifiable, Codable {
    public let id: ConversationID
    public var title: String
    public var lastMessagePreview: String
    public var lastActivityAt: Date
    public var unread: Bool
    public var accountLabel: String
    public var badgeColorHex: String

    public init(
        id: ConversationID,
        title: String,
        lastMessagePreview: String,
        lastActivityAt: Date,
        unread: Bool,
        accountLabel: String,
        badgeColorHex: String
    ) {
        self.id = id
        self.title = title
        self.lastMessagePreview = lastMessagePreview
        self.lastActivityAt = lastActivityAt
        self.unread = unread
        self.accountLabel = accountLabel
        self.badgeColorHex = badgeColorHex
    }
}
