import Foundation

/// Immutable Google identity key: `{issuer}|{sub}`. Email is display-only.
public struct AccountID: Hashable, Codable, Sendable, RawRepresentable {
    public let issuer: String
    public let subject: String

    public init(issuer: String, subject: String) {
        self.issuer = issuer
        self.subject = subject
    }

    public var rawValue: String {
        "\(issuer)|\(subject)"
    }

    public init?(rawValue: String) {
        let parts = rawValue.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty, !parts[1].isEmpty else {
            return nil
        }
        self.issuer = String(parts[0])
        self.subject = String(parts[1])
    }

    public static func parse(_ rawValue: String) throws -> AccountID {
        guard let value = AccountID(rawValue: rawValue) else {
            throw AccountIDError.invalidRawValue(rawValue)
        }
        return value
    }
}

public enum AccountIDError: Error, Equatable {
    case invalidRawValue(String)
}

public struct LinkedAccount: Hashable, Codable, Identifiable, Sendable {
    public let id: AccountID
    public var email: String
    public var label: String
    public var colorHex: String

    public init(id: AccountID, email: String, label: String, colorHex: String) {
        self.id = id
        self.email = email
        self.label = label
        self.colorHex = colorHex
    }

    public var displayLabel: String { label }
}
