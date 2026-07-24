import Foundation
import GRDB

public struct CachedConversation: Codable, FetchableRecord, PersistableRecord, Sendable {
    public static let databaseTableName = "conversations"

    public var id: String
    public var accountIdRaw: String
    public var spaceName: String
    public var accountLabel: String
    public var title: String
    public var lastMessagePreview: String
    public var lastActivity: Date
    public var unread: Bool

    public init(from summary: ConversationSummary) {
        self.id = summary.conversationId.rawValue
        self.accountIdRaw = summary.conversationId.accountId.rawValue
        self.spaceName = summary.conversationId.spaceName
        self.accountLabel = summary.accountLabel
        self.title = summary.title
        self.lastMessagePreview = summary.lastMessagePreview
        self.lastActivity = summary.lastActivity
        self.unread = summary.unread
    }

    public func toSummary(accountId: AccountId) -> ConversationSummary {
        ConversationSummary(
            conversationId: ConversationId(accountId: accountId, spaceName: spaceName),
            accountLabel: accountLabel,
            title: title,
            lastMessagePreview: lastMessagePreview,
            lastActivity: lastActivity,
            unread: unread
        )
    }
}

public enum DatabaseMigrator {
    public static func migrate(_ dbQueue: DatabaseQueue) throws {
        var migrator = GRDB.DatabaseMigrator()
        migrator.registerMigration("v1_conversations") { db in
            try db.create(table: CachedConversation.databaseTableName) { t in
                t.column("id", .text).primaryKey()
                t.column("accountIdRaw", .text).notNull()
                t.column("spaceName", .text).notNull()
                t.column("accountLabel", .text).notNull()
                t.column("title", .text).notNull()
                t.column("lastMessagePreview", .text).notNull()
                t.column("lastActivity", .datetime).notNull()
                t.column("unread", .boolean).notNull()
            }
            try db.create(index: "idx_conversations_lastActivity", on: CachedConversation.databaseTableName, columns: ["lastActivity"])
        }
        try migrator.migrate(dbQueue)
    }
}

public final class ConversationCache: @unchecked Sendable {
    private let dbQueue: DatabaseQueue

    public init(path: String) throws {
        self.dbQueue = try DatabaseQueue(path: path)
        try DatabaseMigrator.migrate(dbQueue)
    }

    public func upsert(_ summary: ConversationSummary) throws {
        let cached = CachedConversation(from: summary)
        try dbQueue.write { db in
            try cached.save(db)
        }
    }

    public func loadAll() throws -> [ConversationSummary] {
        try dbQueue.read { db in
            let rows = try CachedConversation
                .order(Column("lastActivity").desc)
                .fetchAll(db)
            return rows.compactMap { row -> ConversationSummary? in
                guard let accountId = AccountId(rawValue: row.accountIdRaw) else { return nil }
                return row.toSummary(accountId: accountId)
            }
        }
    }
}
