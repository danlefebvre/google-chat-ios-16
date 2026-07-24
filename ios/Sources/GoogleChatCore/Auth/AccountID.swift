import Foundation

public struct AccountID: Hashable, Sendable, Codable {
    public let issuer: String
    public let subject: String
    public var email: String?

    public init(issuer: String, subject: String, email: String? = nil) {
        self.issuer = issuer
        self.subject = subject
        self.email = email
    }

    public var rawValue: String {
        "\(issuer)|\(subject)"
    }

    public var emailDisplay: String? { email }

    public init(rawValue: String) throws {
        let parts = rawValue.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2 else {
            throw AccountIDError.invalidRawValue(rawValue)
        }
        let issuer = String(parts[0])
        let subject = String(parts[1])
        guard !issuer.isEmpty, !subject.isEmpty else {
            throw AccountIDError.invalidRawValue(rawValue)
        }
        self.issuer = issuer
        self.subject = subject
        self.email = nil
    }

    public static func == (lhs: AccountID, rhs: AccountID) -> Bool {
        lhs.issuer == rhs.issuer && lhs.subject == rhs.subject
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(issuer)
        hasher.combine(subject)
    }
}

public enum AccountIDError: Error, Equatable {
    case invalidRawValue(String)
}
