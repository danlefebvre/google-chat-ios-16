import Foundation
#if canImport(Security)
import Security
#endif

/// Keychain-backed multi-account authorization store (iOS / macOS).
public final class KeychainAuthStore: AuthStore, @unchecked Sendable {
    private let service: String
    private let accountKey = "authorizations"
    private let lock = NSLock()

    public init(service: String = "com.googlechatmulti.auth") {
        self.service = service
    }

    public func all() -> [StoredAuthorization] {
        lock.lock()
        defer { lock.unlock() }
        #if canImport(Security)
        return (try? loadUnlocked()) ?? []
        #else
        return []
        #endif
    }

    public func save(_ auth: StoredAuthorization) throws {
        lock.lock()
        defer { lock.unlock() }
        #if canImport(Security)
        var current = try loadUnlocked().filter { $0.account.id != auth.account.id }
        current.append(auth)
        try write(current)
        #else
        throw KeychainError.unavailable
        #endif
    }

    public func remove(id: AccountID) throws {
        lock.lock()
        defer { lock.unlock() }
        #if canImport(Security)
        let current = try loadUnlocked().filter { $0.account.id != id }
        try write(current)
        #else
        throw KeychainError.unavailable
        #endif
    }

    public enum KeychainError: Error {
        case unavailable
        case decodingFailed
        case unexpectedStatus(Int32)
    }

    #if canImport(Security)
    private func loadUnlocked() throws -> [StoredAuthorization] {
        guard let data = readData() else { return [] }
        do {
            return try JSONDecoder().decode([StoredAuthorization].self, from: data)
        } catch {
            throw KeychainError.decodingFailed
        }
    }

    private func write(_ auths: [StoredAuthorization]) throws {
        let data = try JSONEncoder().encode(auths)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: accountKey,
        ]
        SecItemDelete(query as CFDictionary)
        var add = query
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(add as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    private func readData() -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: accountKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else { return nil }
        return item as? Data
    }
    #endif
}
