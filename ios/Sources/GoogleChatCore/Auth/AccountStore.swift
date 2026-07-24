import Foundation

public struct OAuthScopes {
    public static let required: [String] = [
        "openid",
        "email",
        "profile",
        "https://www.googleapis.com/auth/chat.spaces.readonly",
        "https://www.googleapis.com/auth/chat.messages",
        "https://www.googleapis.com/auth/chat.users.readstate",
    ]
}

public struct StoredAccount: Codable, Hashable, Sendable, Identifiable {
    public var id: String { key.id }

    public let key: AccountKey
    public let label: String
    public let color: AccountColor
    public let accessToken: String
    public let refreshToken: String
    public let expiresAt: Date

    public init(
        key: AccountKey,
        label: String,
        color: AccountColor,
        accessToken: String,
        refreshToken: String,
        expiresAt: Date
    ) {
        self.key = key
        self.label = label
        self.color = color
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
    }
}

public protocol AccountStore: Sendable {
    func allAccounts() throws -> [StoredAccount]
    func save(_ account: StoredAccount) throws
    func remove(accountId: String) throws
    func account(for id: String) throws -> StoredAccount?
}

public final class InMemoryAccountStore: AccountStore, @unchecked Sendable {
    private var accounts: [String: StoredAccount] = [:]

    public init() {}

    public func allAccounts() throws -> [StoredAccount] {
        Array(accounts.values)
    }

    public func save(_ account: StoredAccount) throws {
        accounts[account.id] = account
    }

    public func remove(accountId: String) throws {
        accounts.removeValue(forKey: accountId)
    }

    public func account(for id: String) throws -> StoredAccount? {
        accounts[id]
    }
}
