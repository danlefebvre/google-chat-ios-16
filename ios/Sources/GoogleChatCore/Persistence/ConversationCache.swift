import Foundation
import GRDB

public final class ConversationCache {
    private let dbQueue: DatabaseQueue

    public init(databaseURL: URL) throws {
        dbQueue = try DatabaseQueue(path: databaseURL.path)
        try migrator.migrate(dbQueue)
    }

    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1") { db in
            try db.create(table: "conversations") { table in
                table.column("compositeId", .text).primaryKey()
                table.column("accountId", .text).notNull()
                table.column("accountLabel", .text).notNull()
                table.column("accountColor", .text).notNull()
                table.column("spaceResourceName", .text).notNull()
                table.column("title", .text).notNull()
                table.column("preview", .text).notNull()
                table.column("lastActivityAt", .datetime).notNull()
                table.column("unread", .boolean).notNull()
            }
        }
        return migrator
    }

    public func upsert(_ rows: [ConversationRow]) throws {
        try dbQueue.write { db in
            for row in rows {
                try db.execute(
                    sql: """
                    INSERT INTO conversations (
                        compositeId, accountId, accountLabel, accountColor,
                        spaceResourceName, title, preview, lastActivityAt, unread
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                    ON CONFLICT(compositeId) DO UPDATE SET
                        accountLabel = excluded.accountLabel,
                        title = excluded.title,
                        preview = excluded.preview,
                        lastActivityAt = excluded.lastActivityAt,
                        unread = excluded.unread
                    """,
                    arguments: [
                        row.compositeId,
                        row.accountKey.id,
                        row.accountLabel,
                        row.accountColor.rawValue,
                        row.spaceResourceName,
                        row.title,
                        row.preview,
                        row.lastActivityAt,
                        row.unread,
                    ]
                )
            }
        }
    }

    public func fetchAll() throws -> [ConversationRow] {
        try dbQueue.read { db in
            let records = try Row.fetchAll(db, sql: "SELECT * FROM conversations ORDER BY lastActivityAt DESC")
            return records.compactMap(Self.rowToConversation)
        }
    }

    private static func rowToConversation(_ row: Row) -> ConversationRow? {
        guard
            let accountId = row["accountId"] as String?,
            let parts = accountId.split(separator: "|", maxSplits: 1).map(String.init),
            parts.count == 2,
            let accountLabel = row["accountLabel"] as String?,
            let colorRaw = row["accountColor"] as String?,
            let color = AccountColor(rawValue: colorRaw),
            let spaceResourceName = row["spaceResourceName"] as String?,
            let title = row["title"] as String?,
            let preview = row["preview"] as String?,
            let lastActivityAt = row["lastActivityAt"] as Date?,
            let unread = row["unread"] as Bool?
        else {
            return nil
        }

        return ConversationRow(
            accountKey: AccountKey(issuer: parts[0], subject: parts[1]),
            accountLabel: accountLabel,
            accountColor: color,
            spaceResourceName: spaceResourceName,
            title: title,
            preview: preview,
            lastActivityAt: lastActivityAt,
            unread: unread
        )
    }
}
