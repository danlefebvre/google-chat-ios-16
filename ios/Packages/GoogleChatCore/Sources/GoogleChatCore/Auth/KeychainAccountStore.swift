import Foundation
import Security

public enum KeychainAccountStoreError: Error {
    case encodingFailed
    case unhandledStatus(OSStatus)
}

public final class KeychainAccountStore: AccountStore, @unchecked Sendable {
    private let service: String

    public init(service: String = "com.googlechatmulti.accounts") {
        self.service = service
    }

    public func loadAll() throws -> [StoredAccount] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnAttributes as String: true,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return []
        }
        guard status == errSecSuccess else {
            throw KeychainAccountStoreError.unhandledStatus(status)
        }

        guard let items = result as? [[String: Any]] else {
            return []
        }

        let decoder = JSONDecoder()
        return try items.compactMap { item in
            guard let data = item[kSecValueData as String] as? Data else { return nil }
            return try decoder.decode(StoredAccount.self, from: data)
        }
    }

    public func save(_ account: StoredAccount) throws {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(account) else {
            throw KeychainAccountStoreError.encodingFailed
        }

        let accountKey = account.accountId.rawValue
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: accountKey,
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data,
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        }
        if updateStatus == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData as String] = data
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainAccountStoreError.unhandledStatus(addStatus)
            }
            return
        }
        throw KeychainAccountStoreError.unhandledStatus(updateStatus)
    }

    public func remove(accountId: AccountId) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: accountId.rawValue,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainAccountStoreError.unhandledStatus(status)
        }
    }
}
