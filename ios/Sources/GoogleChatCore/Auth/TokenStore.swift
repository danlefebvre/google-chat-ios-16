import Foundation

/// Access/refresh token material for one Google account. Persist only via Keychain on device.
public struct AuthTokens: Hashable, Sendable, Codable {
    public var accessToken: String
    public var refreshToken: String
    public var expiry: Date?

    public init(accessToken: String, refreshToken: String, expiry: Date? = nil) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiry = expiry
    }

    public var isExpired: Bool {
        guard let expiry else { return false }
        return expiry <= Date()
    }
}

public protocol TokenStore: Sendable {
    func save(accountID: AccountID, tokens: AuthTokens) throws
    func load(accountID: AccountID) throws -> AuthTokens?
    func delete(accountID: AccountID) throws
}

public final class InMemoryTokenStore: TokenStore, @unchecked Sendable {
    private var storage: [AccountID: AuthTokens] = [:]
    private let lock = NSLock()

    public init() {}

    public func save(accountID: AccountID, tokens: AuthTokens) throws {
        lock.lock(); defer { lock.unlock() }
        storage[accountID] = tokens
    }

    public func load(accountID: AccountID) throws -> AuthTokens? {
        lock.lock(); defer { lock.unlock() }
        return storage[accountID]
    }

    public func delete(accountID: AccountID) throws {
        lock.lock(); defer { lock.unlock() }
        storage[accountID] = nil
    }
}
