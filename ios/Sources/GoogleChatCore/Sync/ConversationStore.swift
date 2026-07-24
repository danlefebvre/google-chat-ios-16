import Foundation

public protocol ConversationStore: Sendable {
    mutating func upsert(_ conversations: [Conversation]) throws
    mutating func removeAll(for accountID: AccountID) throws
    func all() -> [Conversation]
}

public struct InMemoryConversationStore: ConversationStore {
    private var byID: [ConversationID: Conversation] = [:]

    public init() {}

    public mutating func upsert(_ conversations: [Conversation]) throws {
        for conversation in conversations {
            byID[conversation.id] = conversation
        }
    }

    public mutating func removeAll(for accountID: AccountID) throws {
        byID = byID.filter { $0.key.accountID != accountID }
    }

    public func all() -> [Conversation] {
        Array(byID.values).sorted { $0.lastActivityAt > $1.lastActivityAt }
    }
}
