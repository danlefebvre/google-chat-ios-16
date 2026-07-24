import Foundation

/// Immutable Google account key: issuer + subject (email is display-only).
public struct AccountID: Hashable, Sendable, Codable {
    public var issuer: String
    public var subject: String

    public init(issuer: String, subject: String) {
        self.issuer = issuer
        self.subject = subject
    }

    public var rawValue: String {
        "\(issuer)|\(subject)"
    }

    public init(rawValue: String) throws {
        let parts = rawValue.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty, !parts[1].isEmpty else {
            throw AccountIDError.invalidRawValue(rawValue)
        }
        self.issuer = String(parts[0])
        self.subject = String(parts[1])
    }
}

public enum AccountIDError: Error, Equatable {
    case invalidRawValue(String)
}

public struct Account: Hashable, Sendable, Codable, Identifiable {
    public var id: AccountID
    public var email: String
    public var displayName: String
    public var label: String
    public var badgeColorHex: String

    public init(
        id: AccountID,
        email: String,
        displayName: String,
        label: String,
        badgeColorHex: String
    ) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.label = label
        self.badgeColorHex = badgeColorHex
    }
}

public struct StoredAuthorization: Hashable, Sendable, Codable {
    public var account: Account
    public var refreshToken: String
    public var accessToken: String
    public var expiry: Date

    public init(account: Account, refreshToken: String, accessToken: String, expiry: Date) {
        self.account = account
        self.refreshToken = refreshToken
        self.accessToken = accessToken
        self.expiry = expiry
    }

    public func needsRefresh(at date: Date = Date(), skew: TimeInterval = 60) -> Bool {
        date.addingTimeInterval(skew) >= expiry
    }
}

public protocol AuthStore: AnyObject {
    func all() -> [StoredAuthorization]
    func save(_ auth: StoredAuthorization) throws
    func remove(id: AccountID) throws
}

public final class InMemoryAuthStore: AuthStore, @unchecked Sendable {
    private var byID: [AccountID: StoredAuthorization] = [:]

    public init() {}

    public func all() -> [StoredAuthorization] {
        Array(byID.values).sorted { $0.account.email < $1.account.email }
    }

    public func save(_ auth: StoredAuthorization) throws {
        byID[auth.account.id] = auth
    }

    public func remove(id: AccountID) throws {
        byID[id] = nil
    }
}
