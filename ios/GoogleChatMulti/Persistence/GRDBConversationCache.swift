import Foundation
import GoogleChatMultiCore

#if canImport(SQLite3)
import SQLite3
#endif

/// Lightweight SQLite cache (GRDB-compatible schema). Keeps recent threads offline.
public actor GRDBConversationCache: ConversationCaching {
    private let dbPath: String
    private var db: OpaquePointer?

    public init(filename: String = "inbox-cache.sqlite") {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.dbPath = dir.appendingPathComponent(filename).path
        openAndMigrate()
    }

    deinit {
        if let db {
            sqlite3_close(db)
        }
    }

    public func upsertConversations(_ rows: [ConversationSummary]) async throws {
        for row in rows {
            let sql = """
            INSERT INTO conversations(
              composite_id, account_id, account_label, account_color_hex, space_name,
              title, preview, last_activity, unread_count, is_dm
            ) VALUES (?,?,?,?,?,?,?,?,?,?)
            ON CONFLICT(composite_id) DO UPDATE SET
              account_label=excluded.account_label,
              account_color_hex=excluded.account_color_hex,
              title=excluded.title,
              preview=excluded.preview,
              last_activity=excluded.last_activity,
              unread_count=excluded.unread_count,
              is_dm=excluded.is_dm;
            """
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { continue }
            defer { sqlite3_finalize(stmt) }
            bind(stmt, 1, row.compositeId)
            bind(stmt, 2, row.accountId.rawValue)
            bind(stmt, 3, row.accountLabel)
            bind(stmt, 4, row.accountColorHex)
            bind(stmt, 5, row.spaceName)
            bind(stmt, 6, row.title)
            bind(stmt, 7, row.lastMessagePreview)
            sqlite3_bind_double(stmt, 8, row.lastActivityAt.timeIntervalSince1970)
            sqlite3_bind_int(stmt, 9, Int32(row.unreadCount))
            sqlite3_bind_int(stmt, 10, row.isDirectMessage ? 1 : 0)
            sqlite3_step(stmt)
        }
    }

    public func loadConversations() async throws -> [ConversationSummary] {
        let sql = """
        SELECT account_id, account_label, account_color_hex, space_name, title, preview,
               last_activity, unread_count, is_dm
        FROM conversations;
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }

        var rows: [ConversationSummary] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let accountRaw = string(stmt, 0)
            guard let accountId = AccountID(rawValue: accountRaw) else { continue }
            rows.append(
                ConversationSummary(
                    accountId: accountId,
                    accountLabel: string(stmt, 1),
                    accountColorHex: string(stmt, 2),
                    spaceName: string(stmt, 3),
                    title: string(stmt, 4),
                    lastMessagePreview: string(stmt, 5),
                    lastActivityAt: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 6)),
                    unreadCount: Int(sqlite3_column_int(stmt, 7)),
                    isDirectMessage: sqlite3_column_int(stmt, 8) == 1
                )
            )
        }
        return rows
    }

    private func openAndMigrate() {
        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            db = nil
            return
        }
        let sql = """
        CREATE TABLE IF NOT EXISTS conversations (
          composite_id TEXT PRIMARY KEY,
          account_id TEXT NOT NULL,
          account_label TEXT NOT NULL,
          account_color_hex TEXT NOT NULL,
          space_name TEXT NOT NULL,
          title TEXT NOT NULL,
          preview TEXT NOT NULL,
          last_activity REAL NOT NULL,
          unread_count INTEGER NOT NULL,
          is_dm INTEGER NOT NULL
        );
        """
        sqlite3_exec(db, sql, nil, nil, nil)
    }

    private func bind(_ stmt: OpaquePointer?, _ index: Int32, _ value: String) {
        sqlite3_bind_text(stmt, index, value, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
    }

    private func string(_ stmt: OpaquePointer?, _ index: Int32) -> String {
        guard let c = sqlite3_column_text(stmt, index) else { return "" }
        return String(cString: c)
    }
}
