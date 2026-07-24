import Foundation

/// Simple offline cache of recent threads (JSON file). Production iOS can swap in GRDB.
public struct JSONFileConversationStore: ConversationStore {
    private let fileURL: URL
    private var byID: [ConversationID: Conversation]

    public init(fileURL: URL) throws {
        self.fileURL = fileURL
        if FileManager.default.fileExists(atPath: fileURL.path) {
            let data = try Data(contentsOf: fileURL)
            let rows = try ChatJSON.makeDecoder().decode([Conversation].self, from: data)
            var map: [ConversationID: Conversation] = [:]
            for row in rows { map[row.id] = row }
            self.byID = map
        } else {
            self.byID = [:]
        }
    }

    public mutating func upsert(_ conversations: [Conversation]) {
        for conversation in conversations {
            byID[conversation.id] = conversation
        }
        try? persist()
    }

    public mutating func removeAll(for accountID: AccountID) {
        byID = byID.filter { $0.key.accountID != accountID }
        try? persist()
    }

    public func all() -> [Conversation] {
        Array(byID.values).sorted { $0.lastActivityAt > $1.lastActivityAt }
    }

    private func persist() throws {
        let dir = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let data = try ChatJSON.makeEncoder().encode(Array(byID.values))
        try data.write(to: fileURL, options: .atomic)
    }
}
