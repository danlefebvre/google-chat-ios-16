import Foundation

/// Computes which outbound message should show a “Seen” receipt.
///
/// Google Chat’s public API does not expose peer read receipts. This helper
/// accepts an explicit peer read timestamp when available (e.g. another linked
/// account in the same DM) and otherwise callers can pass a lower-bound time
/// inferred from the peer’s latest reply.
public enum MessageSeenReceipt {
    /// Name of the newest self-authored message at or before `peerLastReadTime`.
    ///
    /// Returns `nil` when a later peer message exists — a reply already proves
    /// the outbound message was seen, so the receipt would be redundant.
    public static func lastSeenSelfMessageName(
        in messages: [ChatMessage],
        selfUserName: String,
        peerLastReadTime: Date?
    ) -> String? {
        let selfName = selfUserName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !selfName.isEmpty, let peerLastReadTime else { return nil }

        var bestName: String?
        var bestTime: Date?
        for message in messages {
            guard message.sender?.name == selfName,
                  let created = message.createTime,
                  created <= peerLastReadTime
            else { continue }
            if let bestTime, created <= bestTime { continue }
            bestTime = created
            bestName = message.name
        }
        guard let bestName, let bestTime else { return nil }

        let peerRepliedAfter = messages.contains { message in
            guard let sender = message.sender?.name, sender != selfName,
                  let created = message.createTime
            else { return false }
            return created > bestTime
        }
        return peerRepliedAfter ? nil : bestName
    }

    /// Lower-bound peer read time from their newest message in `messages`.
    public static func inferredPeerLastReadTime(
        in messages: [ChatMessage],
        selfUserName: String
    ) -> Date? {
        let selfName = selfUserName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !selfName.isEmpty else { return nil }
        return messages
            .compactMap { message -> Date? in
                guard let sender = message.sender?.name, sender != selfName else { return nil }
                return message.createTime
            }
            .max()
    }
}
