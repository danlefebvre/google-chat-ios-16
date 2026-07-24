import Foundation

public protocol AccountStore: Sendable {
    func loadAll() throws -> [StoredAccount]
    func save(_ account: StoredAccount) throws
    func remove(accountId: AccountId) throws
}

public final class InMemoryAccountStore: AccountStore, @unchecked Sendable {
    private var accounts: [String: StoredAccount] = [:]
    private let lock = NSLock()

    public init() {}

    public func loadAll() throws -> [StoredAccount] {
        lock.lock()
        defer { lock.unlock() }
        return Array(accounts.values)
    }

    public func save(_ account: StoredAccount) throws {
        lock.lock()
        defer { lock.unlock() }
        accounts[account.accountId.rawValue] = account
    }

    public func remove(accountId: AccountId) throws {
        lock.lock()
        defer { lock.unlock() }
        accounts.removeValue(forKey: accountId.rawValue)
    }
}
