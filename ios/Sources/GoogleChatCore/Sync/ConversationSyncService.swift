import Foundation

public actor ConversationSyncService {
    private let api: ChatAPIClient
    private let accountStore: AccountStore

    public init(api: ChatAPIClient, accountStore: AccountStore) {
        self.api = api
        self.accountStore = accountStore
    }

    public func syncAllConversations() async throws -> [ConversationRow] {
        let accounts = try accountStore.allAccounts()
        var rows: [ConversationRow] = []

        for account in accounts {
            let spaces = try await api.listSpaces(accessToken: account.accessToken)
            for space in spaces.spaces {
                let messages = try await api.listMessages(
                    spaceResourceName: space.name,
                    accessToken: account.accessToken
                )
                let latest = messages.messages.first
                let preview: String
                if let sender = latest?.sender?.displayName, let text = latest?.text {
                    preview = "\(sender): \(text)"
                } else {
                    preview = ""
                }

                let lastActivity = parseDate(latest?.createTime) ?? .distantPast
                rows.append(
                    ConversationRow(
                        accountKey: account.key,
                        accountLabel: account.label,
                        accountColor: account.color,
                        spaceResourceName: space.name,
                        title: space.displayName ?? space.name,
                        preview: preview,
                        lastActivityAt: lastActivity,
                        unread: false
                    )
                )
            }
        }

        return InboxMerger.merge(rows)
    }

    private func parseDate(_ value: String?) -> Date? {
        guard let value else { return nil }
        return ISO8601DateFormatter().date(from: value)
    }
}
