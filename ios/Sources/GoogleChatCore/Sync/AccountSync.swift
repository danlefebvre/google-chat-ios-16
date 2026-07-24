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
        var token: String? = nil
        repeat {
            let page = try await client.listSpaces(pageToken: token, pageSize: pageSize)
            let rows = page.spaces.map { space in
                ConversationSummary(
                    accountID: accountID,
                    accountLabel: accountLabel,
                    spaceName: space.name,
                    title: space.resolvedTitle,
                    lastMessagePreview: "",
                    lastActivityAt: Date.distantPast,
                    unreadCount: 0,
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
        repeat {
            let page = try await client.listMessages(spaceName: spaceName, pageToken: token, pageSize: pageSize)
            let stamped = page.messages.map { msg in
                var copy = msg
                copy.accountID = accountID
                copy.spaceName = spaceName
                return copy
            }
            try await store.upsertMessages(stamped)
            if let newest = stamped.max(by: { $0.createTime < $1.createTime }) {
                let preview = "\(newest.senderDisplayName): \(newest.text)"
                try await store.upsertConversations([
                    ConversationSummary(
                        accountID: accountID,
                        accountLabel: accountLabel,
                        spaceName: spaceName,
                        title: spaceName,
                        lastMessagePreview: String(preview.prefix(160)),
                        lastActivityAt: newest.createTime,
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
