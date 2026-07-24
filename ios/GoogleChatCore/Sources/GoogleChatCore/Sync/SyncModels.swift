import Foundation

/// Conflict-free upsert helpers for local cache (GRDB layer uses these keys).
public struct SyncKeys {
    public static func messageKey(accountId: AccountId, messageName: String) -> String {
        "\(accountId.rawValue)::\(messageName)"
    }

    public static func spaceKey(accountId: AccountId, spaceName: String) -> String {
        "\(accountId.rawValue)::\(spaceName)"
    }
}

public struct MessagePage {
    public let messages: [ChatMessage]
    public let nextPageToken: String?

    public init(messages: [ChatMessage], nextPageToken: String?) {
        self.messages = messages
        self.nextPageToken = nextPageToken
    }
}

/// Merge fetched messages into an existing list by `createTime` ascending.
public struct MessageMerger {
    public init() {}

    public func merge(existing: [ChatMessage], incoming: [ChatMessage]) -> [ChatMessage] {
        var byName: [String: ChatMessage] = [:]
        for msg in existing + incoming {
            byName[msg.name] = msg
        }
        return byName.values.sorted { $0.createTime < $1.createTime }
    }
}
