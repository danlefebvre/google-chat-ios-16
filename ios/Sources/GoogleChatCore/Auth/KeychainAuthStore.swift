import Foundation

#if os(iOS) || os(macOS)
import Security

/// Keychain-backed multi-account authorization store.
public actor KeychainAuthStore: AuthStore {
    private let service: String

    public init(service: String = "com.danlefebvre.GoogleChatMulti.auth") {
        self.service = service
    }

    public func all() async throws -> [AccountAuthorization] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecMatchLimit as String: kSecMatchLimitAll,
            kSecReturnAttributes as String: true,
            kSecReturnData as String: true,
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return [] }
        guard status == errSecSuccess else { throw KeychainError.unhandled(status) }
        guard let items = result as? [[String: Any]] else { return [] }
        return try items.compactMap { item in
            guard let data = item[kSecValueData as String] as? Data else { return nil }
            return try JSONDecoder().decode(CodableAuth.self, from: data).asAuthorization()
        }
    }

    public func authorization(for accountID: AccountID) async throws -> AccountAuthorization? {
        try await all().first { $0.accountID == accountID }
    }

    public func upsert(_ auth: AccountAuthorization) async throws {
        let payload = try JSONEncoder().encode(CodableAuth(auth))
        let account = auth.accountID.rawValue
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let update: [String: Any] = [kSecValueData as String: payload]
        let status = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        if status == errSecItemNotFound {
            var add = query
            add[kSecValueData as String] = payload
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let addStatus = SecItemAdd(add as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw KeychainError.unhandled(addStatus) }
        } else if status != errSecSuccess {
            throw KeychainError.unhandled(status)
        }
    }

    public func remove(_ accountID: AccountID) async throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: accountID.rawValue,
        ]
        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            throw KeychainError.unhandled(status)
        }
    }
}

public enum KeychainError: Error {
    case unhandled(OSStatus)
}

private struct CodableAuth: Codable {
    var issuer: String
    var subject: String
    var email: String?
    var label: String
    var refreshToken: String
    var accessToken: String
    var accessTokenExpiresAt: Date
    var colorHex: String

    init(_ auth: AccountAuthorization) {
        issuer = auth.accountID.issuer
        subject = auth.accountID.subject
        email = auth.accountID.email
        label = auth.label
        refreshToken = auth.refreshToken
        accessToken = auth.accessToken
        accessTokenExpiresAt = auth.accessTokenExpiresAt
        colorHex = auth.colorHex
    }

    func asAuthorization() -> AccountAuthorization {
        AccountAuthorization(
            accountID: AccountID(issuer: issuer, subject: subject, email: email),
            label: label,
            refreshToken: refreshToken,
            accessToken: accessToken,
            accessTokenExpiresAt: accessTokenExpiresAt,
            colorHex: colorHex
        )
    }
}
#endif
