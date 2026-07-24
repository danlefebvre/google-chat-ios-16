import Foundation

/// Durable account metadata cache (JSON file). Tokens remain in Keychain via `TokenStore`.
public struct JSONFileAccountStore: AccountStore {
    private let fileURL: URL
    private var byID: [AccountID: Account]

    public init(fileURL: URL) throws {
        self.fileURL = fileURL
        if FileManager.default.fileExists(atPath: fileURL.path) {
            let data = try Data(contentsOf: fileURL)
            let rows = try ChatJSON.makeDecoder().decode([Account].self, from: data)
            var map: [AccountID: Account] = [:]
            for row in rows { map[row.id] = row }
            self.byID = map
        } else {
            self.byID = [:]
        }
    }

    public mutating func upsert(_ account: Account) throws {
        let snapshot = byID
        byID[account.id] = account
        do {
            try persist()
        } catch {
            byID = snapshot
            throw error
        }
    }

    public mutating func remove(_ id: AccountID) throws {
        let snapshot = byID
        byID[id] = nil
        do {
            try persist()
        } catch {
            byID = snapshot
            throw error
        }
    }

    public func all() -> [Account] {
        Array(byID.values).sorted { $0.label.localizedStandardCompare($1.label) == .orderedAscending }
    }

    public func get(_ id: AccountID) -> Account? {
        byID[id]
    }

    private func persist() throws {
        let dir = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let data = try ChatJSON.makeEncoder().encode(Array(byID.values))
        try data.write(to: fileURL, options: .atomic)
    }
}
