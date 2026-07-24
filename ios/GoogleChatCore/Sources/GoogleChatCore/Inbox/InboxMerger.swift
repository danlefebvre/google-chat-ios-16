import Foundation

/// One row in the unified home list.
public struct ConversationItem: Identifiable, Hashable, Sendable, Equatable {
    public var id: String { "\(accountId.rawValue):\(spaceName)" }

    public let accountId: AccountId
    public let accountLabel: String
    public let spaceName: String
    public var spaceTitle: String
    public var lastMessagePreview: String
    public var lastActivity: Date
    public var isUnread: Bool

    public init(
        accountId: AccountId,
        accountLabel: String,
        spaceName: String,
        spaceTitle: String,
        lastMessagePreview: String,
        lastActivity: Date,
        isUnread: Bool
    ) {
        self.accountId = accountId
        self.accountLabel = accountLabel
        self.spaceName = spaceName
        self.spaceTitle = spaceTitle
        self.lastMessagePreview = lastMessagePreview
        self.lastActivity = lastActivity
        self.isUnread = isUnread
    }
}

public enum InboxFilter: Sendable, Equatable {
    case all
    case account(AccountId)
}

public enum InboxSort {
    case lastActivityDescending
}

public struct InboxMerger {
    public init() {}

    /// Merge conversation rows from multiple accounts, sorted by last activity.
    public func merge(
        rowsByAccount: [AccountId: [ConversationItem]],
        filter: InboxFilter = .all,
        searchQuery: String = "",
        sort: InboxSort = .lastActivityDescending
    ) -> [ConversationItem] {
        var merged = rowsByAccount.values.flatMap { $0 }

        switch filter {
        case .all:
            break
        case .account(let accountId):
            merged = merged.filter { $0.accountId == accountId }
        }

        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !query.isEmpty {
            merged = merged.filter {
                $0.spaceTitle.lowercased().contains(query)
                    || $0.lastMessagePreview.lowercased().contains(query)
                    || $0.accountLabel.lowercased().contains(query)
            }
        }

        switch sort {
        case .lastActivityDescending:
            merged.sort { $0.lastActivity > $1.lastActivity }
        }

        return merged
    }

    /// Upsert a space row after fetching messages; keeps the latest preview.
    public func upsert(
        rows: [ConversationItem],
        accountId: AccountId,
        accountLabel: String,
        space: ChatSpace,
        latestMessage: ChatMessage?,
        isUnread: Bool
    ) -> [ConversationItem] {
        var result = rows.filter { !($0.accountId == accountId && $0.spaceName == space.name) }

        let preview: String
        let activity: Date
        if let msg = latestMessage {
            preview = "\(msg.senderDisplayName): \(msg.text)"
            activity = msg.createTime
        } else {
            preview = ""
            activity = Date.distantPast
        }

        let item = ConversationItem(
            accountId: accountId,
            accountLabel: accountLabel,
            spaceName: space.name,
            spaceTitle: space.displayName,
            lastMessagePreview: preview,
            lastActivity: activity,
            isUnread: isUnread
        )
        result.append(item)
        return result
    }
}
