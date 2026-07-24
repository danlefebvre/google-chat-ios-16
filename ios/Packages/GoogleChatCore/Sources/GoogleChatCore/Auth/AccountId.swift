import Foundation

public struct AccountId: Hashable, Codable, Sendable {
    public let issuer: String
    public let subject: String
    public let displayEmail: String?

    public init(issuer: String, subject: String, displayEmail: String? = nil) {
        self.issuer = issuer
        self.subject = subject
        self.displayEmail = displayEmail
    }

    public var rawValue: String {
        "\(issuer)|\(subject)"
    }

    public init(rawValue: String) throws {
        let parts = rawValue.split(separator: "|", maxSplits: 1).map(String.init)
        guard parts.count == 2 else {
            throw AccountIdError.invalidRawValue
        }
        self.issuer = parts[0]
        self.subject = parts[1]
        self.displayEmail = nil
    }
}

public enum AccountIdError: Error {
    case invalidRawValue
}

public enum AccountBadgeColor: String, Codable, Sendable {
    case work
    case personal
    case custom
}

public struct StoredAccount: Codable, Hashable, Sendable, Identifiable {
    public var id: AccountId { accountId }
    public let accountId: AccountId
    public let label: String
    public let color: AccountBadgeColor
    public let accessToken: String
    public let refreshToken: String
    public let expiresAt: Date

    public init(
        accountId: AccountId,
        label: String,
        color: AccountBadgeColor,
        accessToken: String,
        refreshToken: String,
        expiresAt: Date
    ) {
        self.accountId = accountId
        self.label = label
        self.color = color
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
    }
}
