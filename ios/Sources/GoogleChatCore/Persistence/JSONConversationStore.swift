import Foundation

/// Offline cache of recent conversations (SQLite/GRDB-equivalent for MVP).
/// Persists Codable rows to a JSON file; safe on iPhone 8 and testable on Linux.
public final class JSONConversationStore: ConversationStore, @unchecked Sendable {
    private let url: URL
    private let lock = NSLock()
    private var byID: [String: ConversationSummary]

    public init(fileURL: URL) throws {
        self.url = fileURL
        if FileManager.default.fileExists(atPath: fileURL.path) {
            let data = try Data(contentsOf: fileURL)
            let rows = try JSONDecoder().decode([ConversationSummary].self, from: data)
            var map: [String: ConversationSummary] = [:]
            for row in rows { map[row.compositeId] = row }
            self.byID = map
        } else {
            self.byID = [:]
            try persistUnlocked()
        }
    }

    public convenience init(directory: URL, fileName: String = "conversations.json") throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try self.init(fileURL: directory.appendingPathComponent(fileName))
    }

    public func all() -> [ConversationSummary] {
        lock.lock()
        defer { lock.unlock() }
        return Array(byID.values)
    }

    public func upsert(_ conversation: ConversationSummary) throws {
        lock.lock()
        defer { lock.unlock() }
        byID[conversation.compositeId] = conversation
        try persistUnlocked()
    }

    public func remove(compositeId: String) throws {
        lock.lock()
        defer { lock.unlock() }
        byID[compositeId] = nil
        try persistUnlocked()
    }

    private func persistUnlocked() throws {
        let rows = Array(byID.values)
        let data = try JSONEncoder().encode(rows)
        try data.write(to: url, options: [.atomic])
    }
}
