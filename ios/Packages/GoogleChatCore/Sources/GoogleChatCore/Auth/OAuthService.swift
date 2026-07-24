import Foundation

public struct OAuthConfiguration: Sendable {
    public let clientID: String
    public let redirectURI: String
    public let scopes: [String]

    public static let chatScopes: [String] = [
        "openid",
        "email",
        "profile",
        "https://www.googleapis.com/auth/chat.spaces.readonly",
        "https://www.googleapis.com/auth/chat.messages",
        "https://www.googleapis.com/auth/chat.users.readstate",
    ]

    public init(clientID: String, redirectURI: String, scopes: [String] = OAuthConfiguration.chatScopes) {
        self.clientID = clientID
        self.redirectURI = redirectURI
        self.scopes = scopes
    }
}

public struct OAuthTokenResponse: Codable, Sendable {
    public let accessToken: String
    public let refreshToken: String?
    public let expiresIn: Int
    public let idToken: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case idToken = "id_token"
    }
}

public struct GoogleIDTokenClaims: Codable, Sendable {
    public let iss: String
    public let sub: String
    public let email: String?
}

public enum OAuthService {
    public static func parseIDTokenClaims(_ idToken: String) throws -> GoogleIDTokenClaims {
        let parts = idToken.split(separator: ".")
        guard parts.count >= 2 else {
            throw OAuthError.invalidIDToken
        }

        var payload = String(parts[1])
        payload = payload.replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let padding = 4 - payload.count % 4
        if padding < 4 {
            payload += String(repeating: "=", count: padding)
        }

        guard let data = Data(base64Encoded: payload) else {
            throw OAuthError.invalidIDToken
        }
        return try JSONDecoder().decode(GoogleIDTokenClaims.self, from: data)
    }

    public static func storedAccount(
        from tokenResponse: OAuthTokenResponse,
        label: String,
        color: AccountBadgeColor,
        now: Date = Date()
    ) throws -> StoredAccount {
        guard let idToken = tokenResponse.idToken else {
            throw OAuthError.missingIDToken
        }
        let claims = try parseIDTokenClaims(idToken)
        let accountId = AccountId(issuer: claims.iss, subject: claims.sub, displayEmail: claims.email)
        let refreshToken = tokenResponse.refreshToken ?? ""
        let expiresAt = now.addingTimeInterval(TimeInterval(tokenResponse.expiresIn))

        return StoredAccount(
            accountId: accountId,
            label: label,
            color: color,
            accessToken: tokenResponse.accessToken,
            refreshToken: refreshToken,
            expiresAt: expiresAt
        )
    }
}

public enum OAuthError: Error {
    case invalidIDToken
    case missingIDToken
}
