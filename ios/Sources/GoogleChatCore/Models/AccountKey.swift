import Foundation

public struct AccountKey: Hashable, Codable, Sendable {
    public let issuer: String
    public let subject: String
    public let email: String?

    public init(issuer: String, subject: String, email: String? = nil) {
        self.issuer = issuer
        self.subject = subject
        self.email = email
    }

    public var id: String {
        "\(issuer)|\(subject)"
    }
}
