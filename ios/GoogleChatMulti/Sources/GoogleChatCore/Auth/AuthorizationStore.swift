import Foundation

public enum OAuthScopes {
    public static let minimal: [String] = [
        "openid",
        "email",
        "profile",
        "https://www.googleapis.com/auth/chat.spaces.readonly",
        "https://www.googleapis.com/auth/chat.messages",
        "https://www.googleapis.com/auth/chat.users.readstate",
    ]
}

public struct StoredAuthorization: Codable, Sendable, Equatable {
    public let accountId: AccountId
    public let accessToken: String
    public let refreshToken: String
    public let expiresAt: Date

    public init(accountId: AccountId, accessToken: String, refreshToken: String, expiresAt: Date) {
        self.accountId = accountId
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
    }

    public var isExpired: Bool {
        expiresAt <= Date()
    }
}

public protocol AuthorizationStore: Sendable {
    func load(accountId: AccountId) throws -> StoredAuthorization?
    func save(_ authorization: StoredAuthorization) throws
    func delete(accountId: AccountId) throws
    func listAccountIds() throws -> [AccountId]
}

/// In-memory store for tests and previews.
public final class InMemoryAuthorizationStore: AuthorizationStore, @unchecked Sendable {
    private var storage: [String: StoredAuthorization] = [:]
    private let lock = NSLock()

    public init() {}

    public func load(accountId: AccountId) throws -> StoredAuthorization? {
        lock.lock()
        defer { lock.unlock() }
        return storage[accountId.rawValue]
    }

    public func save(_ authorization: StoredAuthorization) throws {
        lock.lock()
        defer { lock.unlock() }
        storage[authorization.accountId.rawValue] = authorization
    }

    public func delete(accountId: AccountId) throws {
        lock.lock()
        defer { lock.unlock() }
        storage.removeValue(forKey: accountId.rawValue)
    }

    public func listAccountIds() throws -> [AccountId] {
        lock.lock()
        defer { lock.unlock() }
        return storage.values.map(\.accountId)
    }
}
