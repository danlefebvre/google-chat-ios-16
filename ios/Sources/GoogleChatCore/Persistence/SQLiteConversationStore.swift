import Foundation
import CSQLite

/// Lightweight SQLite offline cache (GRDB-compatible schema; no GRDB dependency required).
public actor SQLiteConversationStore: ConversationStore {
    private let path: String
    private var db: OpaquePointer?

    public init(path: String) throws {
        self.path = path
        if sqlite3_open(path, &db) != SQLITE_OK {
            throw SQLiteStoreError.openFailed(path)
        }
        try exec("""
        CREATE TABLE IF NOT EXISTS conversations (
          composite_id TEXT PRIMARY KEY,
          account_raw TEXT NOT NULL,
          account_label TEXT NOT NULL,
          space_name TEXT NOT NULL,
          title TEXT NOT NULL,
          last_preview TEXT NOT NULL,
          last_activity REAL NOT NULL,
          unread INTEGER NOT NULL,
          is_dm INTEGER NOT NULL
        );
        CREATE TABLE IF NOT EXISTS messages (
          name TEXT PRIMARY KEY,
          account_raw TEXT NOT NULL,
          space_name TEXT NOT NULL,
          text TEXT NOT NULL,
          sender TEXT NOT NULL,
          create_time REAL NOT NULL,
          attachments TEXT NOT NULL
        );
        CREATE INDEX IF NOT EXISTS messages_space_idx
          ON messages(account_raw, space_name, create_time DESC);
        """)
    }

    deinit {
        if let db { sqlite3_close(db) }
    }

    public func upsertConversations(_ rows: [ConversationSummary]) async throws {
        for row in rows {
            try exec("""
            INSERT INTO conversations(composite_id, account_raw, account_label, space_name, title, last_preview, last_activity, unread, is_dm)
            VALUES ('\(escape(row.compositeID))', '\(escape(row.accountID.rawValue))', '\(escape(row.accountLabel))',
                    '\(escape(row.spaceName))', '\(escape(row.title))', '\(escape(row.lastMessagePreview))',
                    \(row.lastActivityAt.timeIntervalSince1970), \(row.unreadCount), \(row.isDM ? 1 : 0))
            ON CONFLICT(composite_id) DO UPDATE SET
              account_label=excluded.account_label,
              title=excluded.title,
              last_preview=excluded.last_preview,
              last_activity=excluded.last_activity,
              unread=excluded.unread,
              is_dm=excluded.is_dm;
            """)
        }
    }

    public func allConversations() async throws -> [ConversationSummary] {
        var out: [ConversationSummary] = []
        let sql = "SELECT account_raw, account_label, space_name, title, last_preview, last_activity, unread, is_dm FROM conversations;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw SQLiteStoreError.prepareFailed
        }
        defer { sqlite3_finalize(stmt) }
        while sqlite3_step(stmt) == SQLITE_ROW {
            guard let accountPtr = sqlite3_column_text(stmt, 0),
                  let labelPtr = sqlite3_column_text(stmt, 1),
                  let spacePtr = sqlite3_column_text(stmt, 2),
                  let titlePtr = sqlite3_column_text(stmt, 3),
                  let previewPtr = sqlite3_column_text(stmt, 4) else {
                continue
            }
            let accountRaw = String(cString: accountPtr)
            let accountID = try AccountID(rawValue: accountRaw)
            out.append(ConversationSummary(
                accountID: accountID,
                accountLabel: String(cString: labelPtr),
                spaceName: String(cString: spacePtr),
                title: String(cString: titlePtr),
                lastMessagePreview: String(cString: previewPtr),
                lastActivityAt: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 5)),
                unreadCount: Int(sqlite3_column_int(stmt, 6)),
                isDM: sqlite3_column_int(stmt, 7) != 0
            ))
        }
        return out
    }

    public func upsertMessages(_ messages: [ChatMessage]) async throws {
        for message in messages {
            let attachments = message.attachmentResourceNames.joined(separator: ",")
            try exec("""
            INSERT INTO messages(name, account_raw, space_name, text, sender, create_time, attachments)
            VALUES ('\(escape(message.name))', '\(escape(message.accountID.rawValue))', '\(escape(message.spaceName))',
                    '\(escape(message.text))', '\(escape(message.senderDisplayName))',
                    \(message.createTime.timeIntervalSince1970), '\(escape(attachments))')
            ON CONFLICT(name) DO UPDATE SET
              text=excluded.text,
              sender=excluded.sender,
              create_time=excluded.create_time,
              attachments=excluded.attachments;
            """)
        }
    }

    public func messages(accountID: AccountID, spaceName: String, limit: Int, before: Date?) async throws -> [ChatMessage] {
        var sql = """
        SELECT name, text, sender, create_time, attachments FROM messages
        WHERE account_raw = '\(escape(accountID.rawValue))' AND space_name = '\(escape(spaceName))'
        """
        if let before {
            sql += " AND create_time < \(before.timeIntervalSince1970)"
        }
        sql += " ORDER BY create_time DESC LIMIT \(limit);"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw SQLiteStoreError.prepareFailed
        }
        defer { sqlite3_finalize(stmt) }
        var out: [ChatMessage] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            guard let namePtr = sqlite3_column_text(stmt, 0),
                  let textPtr = sqlite3_column_text(stmt, 1),
                  let senderPtr = sqlite3_column_text(stmt, 2),
                  let attachmentsPtr = sqlite3_column_text(stmt, 4) else {
                continue
            }
            let attachments = String(cString: attachmentsPtr)
            out.append(ChatMessage(
                name: String(cString: namePtr),
                spaceName: spaceName,
                accountID: accountID,
                text: String(cString: textPtr),
                senderDisplayName: String(cString: senderPtr),
                createTime: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 3)),
                attachmentResourceNames: attachments.isEmpty ? [] : attachments.split(separator: ",").map(String.init)
            ))
        }
        return out
    }

    public func deleteConversations(for accountID: AccountID) async throws {
        try exec("DELETE FROM conversations WHERE account_raw = '\(escape(accountID.rawValue))';")
    }

    public func deleteMessages(for accountID: AccountID) async throws {
        try exec("DELETE FROM messages WHERE account_raw = '\(escape(accountID.rawValue))';")
    }

    private func exec(_ sql: String) throws {
        var err: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(db, sql, nil, nil, &err) != SQLITE_OK {
            let message = err.map { String(cString: $0) } ?? "unknown"
            sqlite3_free(err)
            throw SQLiteStoreError.execFailed(message)
        }
    }

    private func escape(_ value: String) -> String {
        value.replacingOccurrences(of: "'", with: "''")
    }
}

public enum SQLiteStoreError: Error, Equatable {
    case openFailed(String)
    case prepareFailed
    case execFailed(String)
}
