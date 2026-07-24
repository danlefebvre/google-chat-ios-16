import Foundation
import GoogleChatMultiCore
import Security

public protocol AccountAuthStore: AnyObject {
    func loadAccounts() -> [LinkedAccount]
    func save(account: LinkedAccount, refreshToken: String, accessToken: String)
    func remove(accountId: AccountID)
    func accessToken(for accountId: AccountID) -> String?
    func refreshToken(for accountId: AccountID) -> String?
    func asTokenProvider() -> any TokenProviding
}

/// Multi-account Keychain store keyed by immutable `{issuer}|{sub}`.
public final class KeychainAccountAuthStore: AccountAuthStore {
    private let service = "com.googlechatmulti.auth"
    private let accountsKey = "linked-accounts"

    public init() {}

    public func loadAccounts() -> [LinkedAccount] {
        guard let data = read(key: accountsKey),
              let accounts = try? JSONDecoder().decode([LinkedAccount].self, from: data)
        else {
            return []
        }
        return accounts
    }

    public func save(account: LinkedAccount, refreshToken: String, accessToken: String) {
        var accounts = loadAccounts().filter { $0.id != account.id }
        accounts.append(account)
        if let data = try? JSONEncoder().encode(accounts) {
            write(key: accountsKey, data: data)
        }
        if let refreshData = refreshToken.data(using: .utf8) {
            write(key: tokenKey(account.id, kind: "refresh"), data: refreshData)
        }
        if let accessData = accessToken.data(using: .utf8) {
            write(key: tokenKey(account.id, kind: "access"), data: accessData)
        }
    }

    public func remove(accountId: AccountID) {
        let accounts = loadAccounts().filter { $0.id != accountId }
        if let data = try? JSONEncoder().encode(accounts) {
            write(key: accountsKey, data: data)
        }
        delete(key: tokenKey(accountId, kind: "refresh"))
        delete(key: tokenKey(accountId, kind: "access"))
    }

    public func accessToken(for accountId: AccountID) -> String? {
        guard let data = read(key: tokenKey(accountId, kind: "access")) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public func refreshToken(for accountId: AccountID) -> String? {
        guard let data = read(key: tokenKey(accountId, kind: "refresh")) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public func asTokenProvider() -> any TokenProviding {
        AuthTokenProvider(store: self)
    }

    private func tokenKey(_ accountId: AccountID, kind: String) -> String {
        "\(kind):\(accountId.rawValue)"
    }

    private func write(key: String, data: Data) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
        var add = query
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(add as CFDictionary, nil)
    }

    private func read(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else { return nil }
        return item as? Data
    }

    private func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

private struct AuthTokenProvider: TokenProviding {
    let store: AccountAuthStore

    func accessToken(for accountId: AccountID) async throws -> String {
        if let token = store.accessToken(for: accountId) {
            return token
        }
        throw ChatAPIError.httpStatus(401)
    }
}

#if DEBUG
public final class InMemoryAccountAuthStore: AccountAuthStore {
    private var accounts: [LinkedAccount] = []
    private var access: [String: String] = [:]
    private var refresh: [String: String] = [:]

    public init() {}

    public func loadAccounts() -> [LinkedAccount] { accounts }

    public func save(account: LinkedAccount, refreshToken: String, accessToken: String) {
        accounts.removeAll { $0.id == account.id }
        accounts.append(account)
        access[account.id.rawValue] = accessToken
        refresh[account.id.rawValue] = refreshToken
    }

    public func remove(accountId: AccountID) {
        accounts.removeAll { $0.id == accountId }
        access[accountId.rawValue] = nil
        refresh[accountId.rawValue] = nil
    }

    public func accessToken(for accountId: AccountID) -> String? {
        access[accountId.rawValue]
    }

    public func refreshToken(for accountId: AccountID) -> String? {
        refresh[accountId.rawValue]
    }

    public func asTokenProvider() -> any TokenProviding {
        AuthTokenProvider(store: self)
    }
}
#endif
