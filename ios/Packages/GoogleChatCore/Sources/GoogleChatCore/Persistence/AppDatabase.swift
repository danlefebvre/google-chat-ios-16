import Foundation
import GRDB

public struct CachedConversation: Codable, FetchableRecord, PersistableRecord, Identifiable {
    public static let databaseTableName = "conversations"

    public var id: String { compositeId }
    public let compositeId: String
    public let accountIdRaw: String
    public let accountLabel: String
    public let accountColorRaw: String
    public let spaceResourceName: String
    public let title: String
    public let lastMessagePreview: String
    public let lastActivity: Date
    public let unread: Bool

    public init(snapshot: ConversationSnapshot) {
        compositeId = snapshot.compositeId
        accountIdRaw = snapshot.accountId.rawValue
        accountLabel = snapshot.accountLabel
        accountColorRaw = snapshot.accountColor.rawValue
        spaceResourceName = snapshot.spaceResourceName
        title = snapshot.title
        lastMessagePreview = snapshot.lastMessagePreview
        lastActivity = snapshot.lastActivity
        unread = snapshot.unread
    }

    public func toSnapshot(accountId: AccountId) -> ConversationSnapshot {
        ConversationSnapshot(
            accountId: accountId,
            accountLabel: accountLabel,
            accountColor: AccountBadgeColor(rawValue: accountColorRaw) ?? .custom,
            spaceResourceName: spaceResourceName,
            title: title,
            lastMessagePreview: lastMessagePreview,
            lastActivity: lastActivity,
            unread: unread
        )
    }
}

public struct CachedMessage: Codable, FetchableRecord, PersistableRecord, Identifiable {
    public static let databaseTableName = "messages"

    public let id: String
    public let compositeConversationId: String
    public let senderName: String
    public let text: String
    public let createdAt: Date

    public init(message: ChatMessage, compositeConversationId: String, createdAt: Date) {
        id = message.name
        self.compositeConversationId = compositeConversationId
        senderName = message.sender?.displayName ?? "Someone"
        text = message.text ?? ""
        self.createdAt = createdAt
    }
}

public enum AppDatabase {
    public static func makeQueue() throws -> DatabaseQueue {
        let url = try FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("GoogleChatMulti", isDirectory: true)

        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        let dbURL = url.appendingPathComponent("chat.sqlite")

        let queue = try DatabaseQueue(path: dbURL.path)
        try migrator.migrate(queue)
        return queue
    }

    private static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1") { db in
            try db.create(table: "conversations") { table in
                table.column("compositeId", .text).primaryKey()
                table.column("accountIdRaw", .text).notNull()
                table.column("accountLabel", .text).notNull()
                table.column("accountColorRaw", .text).notNull()
                table.column("spaceResourceName", .text).notNull()
                table.column("title", .text).notNull()
                table.column("lastMessagePreview", .text).notNull()
                table.column("lastActivity", .datetime).notNull()
                table.column("unread", .boolean).notNull()
            }

            try db.create(table: "messages") { table in
                table.column("id", .text).primaryKey()
                table.column("compositeConversationId", .text).notNull().indexed()
                table.column("senderName", .text).notNull()
                table.column("text", .text).notNull()
                table.column("createdAt", .datetime).notNull()
            }
        }

        return migrator
    }
}

public struct ConversationRepository {
    private let dbQueue: DatabaseQueue

    public init(dbQueue: DatabaseQueue) {
        self.dbQueue = dbQueue
    }

    public func upsert(_ snapshots: [ConversationSnapshot]) throws {
        try dbQueue.write { db in
            for snapshot in snapshots {
                try CachedConversation(snapshot: snapshot).save(db)
            }
        }
    }

    public func fetchAll() throws -> [ConversationSnapshot] {
        try dbQueue.read { db in
            let rows = try CachedConversation.fetchAll(db)
            return try rows.map { row in
                let accountId = try AccountId(rawValue: row.accountIdRaw)
                return row.toSnapshot(accountId: accountId)
            }
        }
    }
}
