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
    /// True when local Keychain save succeeded but relay registration has not.
    public var relayRegistrationPending: Bool

    private enum CodingKeys: String, CodingKey {
        case id, email, label, colorHex, relayRegistrationPending
    }

    public init(
        id: AccountID,
        email: String,
        label: String,
        colorHex: String,
        relayRegistrationPending: Bool = false
    ) {
        self.id = id
        self.email = email
        self.label = label
        self.colorHex = colorHex
        self.relayRegistrationPending = relayRegistrationPending
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(AccountID.self, forKey: .id)
        email = try container.decode(String.self, forKey: .email)
        label = try container.decode(String.self, forKey: .label)
        colorHex = try container.decode(String.self, forKey: .colorHex)
        relayRegistrationPending =
            try container.decodeIfPresent(Bool.self, forKey: .relayRegistrationPending) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(email, forKey: .email)
        try container.encode(label, forKey: .label)
        try container.encode(colorHex, forKey: .colorHex)
        try container.encode(relayRegistrationPending, forKey: .relayRegistrationPending)
    }

    public var displayLabel: String { label }
}
