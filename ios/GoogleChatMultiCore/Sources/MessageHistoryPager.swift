import Foundation

/// Helpers for paginated chat history (newest-first lists from Google Chat `orderBy=createTime desc`).
public enum MessageHistoryPager {
    /// Appends an older page onto an existing newest-first history, skipping duplicates by message name.
    public static func mergingOlderPage(
        _ existing: [ChatMessage],
        olderPage: [ChatMessage]
    ) -> [ChatMessage] {
        var seen = Set(existing.map(\.name))
        var merged = existing
        for message in olderPage where seen.insert(message.name).inserted {
            merged.append(message)
        }
        return merged
    }

    /// True when Google Chat returned another page token for older messages.
    public static func hasMorePages(nextPageToken: String?) -> Bool {
        guard let nextPageToken else { return false }
        return !nextPageToken.isEmpty
    }
}
