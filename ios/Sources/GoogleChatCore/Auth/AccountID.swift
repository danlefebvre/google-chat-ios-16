import Foundation

/// Immutable Google identity key: `{issuer, sub}`. Email is display-only.
public struct AccountID: Hashable, Sendable, Codable {
    public let issuer: String
    public let subject: String

    public init(issuer: String, subject: String) {
        self.issuer = issuer
        self.subject = subject
    }

    public var key: String { "\(issuer)|\(subject)" }

    public init(key: String) throws {
        let parts = key.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2 else {
            throw AccountIDError.invalidKey(key)
        }
        self.issuer = String(parts[0])
        self.subject = String(parts[1])
    }
}

public enum AccountIDError: Error, Equatable {
    case invalidKey(String)
}

public struct Account: Hashable, Sendable, Identifiable, Codable {
    public let id: AccountID
    public var email: String
    public var label: String
    public var badgeColorHex: String

    public init(id: AccountID, email: String, label: String, badgeColorHex: String) {
        self.id = id
        self.email = email
        self.label = label
        self.badgeColorHex = badgeColorHex
    }
}
