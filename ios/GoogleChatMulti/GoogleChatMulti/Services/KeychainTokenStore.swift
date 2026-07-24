import Foundation
import GoogleChatCore
import Security

/// Keychain-backed token storage for N concurrent Google accounts.
public final class KeychainTokenStore {
  private let service = "com.googlechatmulti.tokens"

  public init() {}

  public func saveTokens(
    accessToken: String,
    refreshToken: String,
    for accountId: AccountId
  ) throws {
    try save(key: accessKey(accountId), value: accessToken)
    try save(key: refreshKey(accountId), value: refreshToken)
  }

  public func accessToken(for accountId: AccountId) throws -> String? {
    try load(key: accessKey(accountId))
  }

  public func refreshToken(for accountId: AccountId) throws -> String? {
    try load(key: refreshKey(accountId))
  }

  public func deleteTokens(for accountId: AccountId) throws {
    try delete(key: accessKey(accountId))
    try delete(key: refreshKey(accountId))
  }

  private func accessKey(_ id: AccountId) -> String { "\(id.rawValue)::access" }
  private func refreshKey(_ id: AccountId) -> String { "\(id.rawValue)::refresh" }

  private func save(key: String, value: String) throws {
    let data = Data(value.utf8)
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: key,
      kSecValueData as String: data,
    ]
    SecItemDelete(query as CFDictionary)
    let status = SecItemAdd(query as CFDictionary, nil)
    guard status == errSecSuccess else {
      throw KeychainError.saveFailed(status)
    }
  }

  private func load(key: String) throws -> String? {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: key,
      kSecReturnData as String: true,
    ]
    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    if status == errSecItemNotFound { return nil }
    guard status == errSecSuccess, let data = item as? Data else {
      throw KeychainError.loadFailed(status)
    }
    return String(data: data, encoding: .utf8)
  }

  private func delete(key: String) throws {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: key,
    ]
    let status = SecItemDelete(query as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else {
      throw KeychainError.deleteFailed(status)
    }
  }
}

public enum KeychainError: Error {
  case saveFailed(OSStatus)
  case loadFailed(OSStatus)
  case deleteFailed(OSStatus)
}
