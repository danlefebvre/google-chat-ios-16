import Foundation

public protocol AccountStore: Sendable {
    mutating func upsert(_ account: Account)
    mutating func remove(_ id: AccountID)
    func all() -> [Account]
    func get(_ id: AccountID) -> Account?
}

public struct InMemoryAccountStore: AccountStore {
    private var byID: [AccountID: Account] = [:]

    public init() {}

    public mutating func upsert(_ account: Account) {
        byID[account.id] = account
    }

    public mutating func remove(_ id: AccountID) {
        byID[id] = nil
    }

    public func all() -> [Account] {
        Array(byID.values).sorted { $0.label.localizedStandardCompare($1.label) == .orderedAscending }
    }

    public func get(_ id: AccountID) -> Account? {
        byID[id]
    }
}
