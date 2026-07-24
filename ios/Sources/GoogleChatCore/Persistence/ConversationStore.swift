import Foundation

public protocol ConversationStore: Sendable {
    func upsertConversations(_ rows: [ConversationSummary]) async throws
    func allConversations() async throws -> [ConversationSummary]
    func upsertMessages(_ messages: [ChatMessage]) async throws
    func messages(accountID: AccountID, spaceName: String, limit: Int, before: Date?) async throws -> [ChatMessage]
}

public actor InMemoryConversationStore: ConversationStore, ConversationCacheWiping {
    private var conversations: [String: ConversationSummary] = [:]
    private var messagesBySpace: [String: [ChatMessage]] = [:]

    public init() {}

    public func upsertConversations(_ rows: [ConversationSummary]) async throws {
        for row in rows {
            conversations[row.compositeID] = row
        }
    }

    public func allConversations() async throws -> [ConversationSummary] {
        Array(conversations.values)
    }

    public func upsertMessages(_ messages: [ChatMessage]) async throws {
        for message in messages {
            let key = "\(message.accountID.rawValue):\(message.spaceName)"
            var list = messagesBySpace[key] ?? []
            if let idx = list.firstIndex(where: { $0.name == message.name }) {
                list[idx] = message
            } else {
                list.append(message)
            }
            messagesBySpace[key] = list
        }
    }

    public func messages(accountID: AccountID, spaceName: String, limit: Int, before: Date?) async throws -> [ChatMessage] {
        let key = "\(accountID.rawValue):\(spaceName)"
        var list = messagesBySpace[key] ?? []
        list.sort { $0.createTime > $1.createTime }
        if let before {
            list = list.filter { $0.createTime < before }
        }
        if list.count > limit {
            return Array(list.prefix(limit))
        }
        return list
    }

    public func deleteConversations(for accountID: AccountID) async throws {
        conversations = conversations.filter { $0.value.accountID != accountID }
    }

    public func deleteMessages(for accountID: AccountID) async throws {
        messagesBySpace = messagesBySpace.filter { !$0.key.hasPrefix(accountID.rawValue + ":") }
    }
}
