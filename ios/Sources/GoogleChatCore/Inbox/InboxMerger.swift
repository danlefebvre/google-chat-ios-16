import Foundation

public enum InboxFilter: Hashable, Sendable {
    case all
    case account(AccountID)
}

public enum InboxMerger {
    public static func merge(accountConversations: [AccountID: [Conversation]]) -> [Conversation] {
        accountConversations.values
            .flatMap { $0 }
            .sorted { $0.lastActivityAt > $1.lastActivityAt }
    }

    public static func filter(_ items: [Conversation], by filter: InboxFilter) -> [Conversation] {
        switch filter {
        case .all:
            return items
        case .account(let accountID):
            return items.filter { $0.id.accountID == accountID }
        }
    }

    public static func search(_ items: [Conversation], query: String) -> [Conversation] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return items }
        return items.filter {
            $0.title.localizedCaseInsensitiveContains(q)
                || $0.lastMessagePreview.localizedCaseInsensitiveContains(q)
        }
    }
}
