import Foundation

public struct InboxMerger: Sendable {
    public init() {}

    /// Merge conversations from multiple accounts, sorted by last activity descending.
    public func merge(_ conversations: [ConversationSummary]) -> [ConversationSummary] {
        conversations.sorted { $0.lastActivity > $1.lastActivity }
    }

    public func filter(
        _ conversations: [ConversationSummary],
        by accountFilter: AccountFilter
    ) -> [ConversationSummary] {
        switch accountFilter {
        case .all:
            return conversations
        case .account(let accountId):
            return conversations.filter { $0.conversationId.accountId == accountId }
        }
    }

    public func search(_ conversations: [ConversationSummary], query: String) -> [ConversationSummary] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return conversations }
        let needle = trimmed.lowercased()
        return conversations.filter {
            $0.title.lowercased().contains(needle)
                || $0.lastMessagePreview.lowercased().contains(needle)
                || $0.accountLabel.lowercased().contains(needle)
        }
    }
}

public struct MessagePreviewFormatter: Sendable {
    public init() {}

    public func preview(senderName: String, text: String, maxLength: Int = 80) -> String {
        guard maxLength > 0 else { return "" }
        let body = "\(senderName): \(text)"
        guard body.count > maxLength else { return body }
        let end = body.index(body.startIndex, offsetBy: maxLength - 1)
        return String(body[..<end]) + "…"
    }
}
