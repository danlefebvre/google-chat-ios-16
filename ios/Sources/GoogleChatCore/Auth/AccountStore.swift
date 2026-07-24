import Foundation

public protocol AccountStore: Sendable {
    mutating func upsert(_ account: Account) throws
    mutating func remove(_ id: AccountID) throws
    func all() -> [Account]
    func get(_ id: AccountID) -> Account?
}

public struct InMemoryAccountStore: AccountStore {
    private var byID: [AccountID: Account] = [:]

    public init() {}

    public mutating func upsert(_ account: Account) throws {
        byID[account.id] = account
    }

    public mutating func remove(_ id: AccountID) throws {
        byID[id] = nil
    }

    public func all() -> [Account] {
        Array(byID.values).sorted { $0.label.localizedStandardCompare($1.label) == .orderedAscending }
    }

    public func get(_ id: AccountID) -> Account? {
        byID[id]
    }
}
