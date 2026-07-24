import Foundation

public enum InboxMerger {
    public static func merge(_ rows: [ConversationRow]) -> [ConversationRow] {
        rows.sorted { $0.lastActivityAt > $1.lastActivityAt }
    }

    public static func filter(_ rows: [ConversationRow], accountLabel: String?) -> [ConversationRow] {
        guard let accountLabel, !accountLabel.isEmpty else {
            return rows
        }
        return rows.filter { $0.accountLabel == accountLabel }
    }

    public static func search(_ rows: [ConversationRow], query: String) -> [ConversationRow] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return rows }
        let needle = trimmed.lowercased()
        return rows.filter {
            $0.title.lowercased().contains(needle) || $0.preview.lowercased().contains(needle)
        }
    }
}
