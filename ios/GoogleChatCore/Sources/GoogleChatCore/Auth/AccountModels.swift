import Foundation

/// Immutable account key: `{issuer}|{sub}` per PLAN.md.
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

    public static func parse(_ raw: String) -> AccountId? {
        let parts = raw.split(separator: "|", maxSplits: 1).map(String.init)
        guard parts.count == 2, !parts[0].isEmpty, !parts[1].isEmpty else {
            return nil
        }
        return AccountId(issuer: parts[0], sub: parts[1])
    }
}

public struct AccountProfile: Identifiable, Codable, Sendable, Equatable {
    public var id: AccountId { accountId }
    public let accountId: AccountId
    public var email: String
    public var displayLabel: String
    public var badgeColorHex: String

    public init(
        accountId: AccountId,
        email: String,
        displayLabel: String,
        badgeColorHex: String
    ) {
        self.accountId = accountId
        self.email = email
        self.displayLabel = displayLabel
        self.badgeColorHex = badgeColorHex
    }
}

/// OAuth scopes for MVP per PLAN.md.
public enum OAuthScopes {
    public static let all: [String] = [
        "openid",
        "email",
        "profile",
        "https://www.googleapis.com/auth/chat.spaces.readonly",
        "https://www.googleapis.com/auth/chat.messages",
        "https://www.googleapis.com/auth/chat.users.readstate",
    ]

    public static var spaceDelimited: String {
        all.joined(separator: " ")
    }
}
