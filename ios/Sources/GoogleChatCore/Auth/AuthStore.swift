import Foundation

public struct AccountAuthorization: Sendable, Equatable {
    public var accountID: AccountID
    public var label: String
    public var refreshToken: String
    public var accessToken: String
    public var accessTokenExpiresAt: Date
    public var colorHex: String

    public init(
        accountID: AccountID,
        label: String,
        refreshToken: String,
        accessToken: String,
        accessTokenExpiresAt: Date,
        colorHex: String = "#3B82F6"
    ) {
        self.accountID = accountID
        self.label = label
        self.refreshToken = refreshToken
        self.accessToken = accessToken
        self.accessTokenExpiresAt = accessTokenExpiresAt
        self.colorHex = colorHex
    }
}

public protocol AuthStore: Sendable {
    func all() async throws -> [AccountAuthorization]
    func authorization(for accountID: AccountID) async throws -> AccountAuthorization?
    func upsert(_ auth: AccountAuthorization) async throws
    func remove(_ accountID: AccountID) async throws
}

public actor InMemoryAuthStore: AuthStore {
    private var byID: [AccountID: AccountAuthorization] = [:]

    public init() {}

    public func all() async throws -> [AccountAuthorization] {
        Array(byID.values).sorted { $0.label < $1.label }
    }

    public func authorization(for accountID: AccountID) async throws -> AccountAuthorization? {
        byID[accountID]
    }

    public func upsert(_ auth: AccountAuthorization) async throws {
        byID[auth.accountID] = auth
    }

    public func remove(_ accountID: AccountID) async throws {
        byID[accountID] = nil
    }
}

public protocol TokenRefresher: Sendable {
    func refresh(refreshToken: String) async throws -> (accessToken: String, expiresAt: Date)
}

public struct MockTokenRefresher: TokenRefresher {
    private let handler: @Sendable (String) async throws -> (String, Date)

    public init(_ handler: @escaping @Sendable (String) async throws -> (String, Date)) {
        self.handler = handler
    }

    public func refresh(refreshToken: String) async throws -> (accessToken: String, expiresAt: Date) {
        try await handler(refreshToken)
    }
}

public actor TokenProvider {
    private let store: AuthStore
    private let refresher: TokenRefresher
    private let skew: TimeInterval

    public init(store: AuthStore, refresher: TokenRefresher, skew: TimeInterval = 60) {
        self.store = store
        self.refresher = refresher
        self.skew = skew
    }

    public func validAccessToken(for accountID: AccountID) async throws -> String {
        guard var auth = try await store.authorization(for: accountID) else {
            throw TokenProviderError.unknownAccount
        }
        if auth.accessTokenExpiresAt.timeIntervalSinceNow > skew {
            return auth.accessToken
        }
        let refreshed = try await refresher.refresh(refreshToken: auth.refreshToken)
        auth.accessToken = refreshed.accessToken
        auth.accessTokenExpiresAt = refreshed.expiresAt
        try await store.upsert(auth)
        return auth.accessToken
    }
}

public enum TokenProviderError: Error {
    case unknownAccount
}
