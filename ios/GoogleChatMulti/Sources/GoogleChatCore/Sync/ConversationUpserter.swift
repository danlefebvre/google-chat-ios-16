import Foundation

public struct ConversationUpserter: Sendable {
    public init() {}

    public func upsert(
        existing: [ConversationSummary],
        incoming: ConversationSummary
    ) -> [ConversationSummary] {
        var result = existing.filter { $0.conversationId != incoming.conversationId }
        result.append(incoming)
        return result
    }

    public func upsertMany(
        existing: [ConversationSummary],
        incoming: [ConversationSummary]
    ) -> [ConversationSummary] {
        var byId: [String: ConversationSummary] = Dictionary(
            uniqueKeysWithValues: existing.map { ($0.conversationId.rawValue, $0) }
        )
        for item in incoming {
            byId[item.conversationId.rawValue] = item
        }
        return Array(byId.values)
    }
}
