import Foundation

public protocol ConversationStore: AnyObject {
    func all() -> [ConversationSummary]
    func upsert(_ conversation: ConversationSummary)
    func remove(compositeId: String)
}

public final class InMemoryConversationStore: ConversationStore, @unchecked Sendable {
    private var byID: [String: ConversationSummary] = [:]

    public init() {}

    public func all() -> [ConversationSummary] {
        Array(byID.values)
    }

    public func upsert(_ conversation: ConversationSummary) {
        byID[conversation.compositeId] = conversation
    }

    public func remove(compositeId: String) {
        byID[compositeId] = nil
    }
}

/// Per-account fetcher that upserts spaces into a shared conversation store.
public struct SpaceSyncService {
    public var client: ChatClient

    public init(client: ChatClient) {
        self.client = client
    }

    public func syncAccount(
        auth: StoredAuthorization,
        into store: ConversationStore,
        previewProvider: (ChatSpace) -> String = { _ in "" }
    ) async throws {
        var token: String? = nil
        repeat {
            let page = try await client.listSpaces(accessToken: auth.accessToken, pageToken: token)
            for space in page.spaces {
                let title: String
                if let name = space.displayName, !name.isEmpty {
                    title = name
                } else if space.spaceType == .directMessage {
                    title = "DM"
                } else {
                    title = space.name
                }
                let summary = ConversationSummary(
                    accountId: auth.account.id,
                    spaceName: space.name,
                    title: title,
                    lastMessagePreview: previewProvider(space),
                    lastActivityAt: space.lastActiveTime ?? .distantPast,
                    unreadCount: 0,
                    accountLabel: auth.account.label,
                    badgeColorHex: auth.account.badgeColorHex
                )
                store.upsert(summary)
            }
            token = page.nextPageToken
        } while token != nil
    }
}
