import Foundation

public struct AccountSync: Sendable {
    public var client: ChatAPIClient
    public var store: ConversationStore
    public var accountLabel: String
    public var pageSize: Int

    public init(client: ChatAPIClient, store: ConversationStore, accountLabel: String, pageSize: Int = 50) {
        self.client = client
        self.store = store
        self.accountLabel = accountLabel
        self.pageSize = pageSize
    }

    public func syncSpaces(accountID: AccountID) async throws {
        let existing = Dictionary(
            uniqueKeysWithValues: try await store.allConversations().map { ($0.compositeID, $0) }
        )
        var token: String? = nil
        repeat {
            let page = try await client.listSpaces(pageToken: token, pageSize: pageSize)
            let rows = page.spaces.map { space in
                let compositeID = "\(accountID.rawValue):\(space.name)"
                let previous = existing[compositeID]
                return ConversationSummary(
                    accountID: accountID,
                    accountLabel: accountLabel,
                    spaceName: space.name,
                    title: space.resolvedTitle,
                    lastMessagePreview: previous?.lastMessagePreview ?? "",
                    lastActivityAt: previous?.lastActivityAt ?? Date.distantPast,
                    unreadCount: previous?.unreadCount ?? 0,
                    isDM: space.isDirectMessage
                )
            }
            try await store.upsertConversations(rows)
            token = page.nextPageToken
        } while token?.isEmpty == false
    }

    public func syncMessages(accountID: AccountID, spaceName: String, maxPages: Int = 3) async throws {
        var token: String? = nil
        var pages = 0
        var bestActivity = Date.distantPast
        var bestPreview = ""
        // Prefer any previously synced activity so older pages cannot clobber it.
        let compositeID = "\(accountID.rawValue):\(spaceName)"
        if let previous = try await store.allConversations().first(where: { $0.compositeID == compositeID }) {
            bestActivity = previous.lastActivityAt
            bestPreview = previous.lastMessagePreview
        }
        repeat {
            let page = try await client.listMessages(spaceName: spaceName, pageToken: token, pageSize: pageSize)
            let stamped = page.messages.map { msg in
                var copy = msg
                copy.accountID = accountID
                copy.spaceName = spaceName
                return copy
            }
            try await store.upsertMessages(stamped)
            if let newest = stamped.max(by: { $0.createTime < $1.createTime }),
               newest.createTime >= bestActivity {
                bestActivity = newest.createTime
                bestPreview = String("\(newest.senderDisplayName): \(newest.text)".prefix(160))
                try await store.upsertConversations([
                    ConversationSummary(
                        accountID: accountID,
                        accountLabel: accountLabel,
                        spaceName: spaceName,
                        title: spaceName,
                        lastMessagePreview: bestPreview,
                        lastActivityAt: bestActivity,
                        unreadCount: 0,
                        isDM: false
                    ),
                ])
            }
            token = page.nextPageToken
            pages += 1
        } while token?.isEmpty == false && pages < maxPages
    }
}
