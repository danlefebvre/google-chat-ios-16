import Foundation

public struct ConversationSyncer {
    private let api: ChatAPIClient
    private let repository: ConversationRepository

    public init(api: ChatAPIClient, repository: ConversationRepository) {
        self.api = api
        self.repository = repository
    }

    public func syncAccount(
        account: StoredAccount,
        now: Date = Date()
    ) async throws -> [ConversationSnapshot] {
        var snapshots: [ConversationSnapshot] = []
        var pageToken: String?

        repeat {
            let response = try await api.listSpaces(
                accessToken: account.accessToken,
                pageToken: pageToken
            )

            for space in response.spaces {
                let messages = try await api.listMessages(
                    accessToken: account.accessToken,
                    spaceName: space.name,
                    pageSize: 1
                )

                let preview = messages.messages.first?.text ?? ""
                let lastActivity = messages.messages.first
                    .flatMap { Self.parseDate($0.createTime) } ?? now

                snapshots.append(
                    ConversationSnapshot(
                        accountId: account.accountId,
                        accountLabel: account.label,
                        accountColor: account.color,
                        spaceResourceName: space.name,
                        title: space.displayName ?? space.name,
                        lastMessagePreview: preview,
                        lastActivity: lastActivity,
                        unread: false
                    )
                )
            }

            pageToken = response.nextPageToken
        } while pageToken != nil

        try repository.upsert(snapshots)
        return ConversationMerger.merge(snapshots)
    }

    private static func parseDate(_ value: String?) -> Date? {
        guard let value else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) {
            return date
        }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }
}
