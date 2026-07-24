import Foundation

public enum SpaceType: String, Codable, Sendable {
    case space = "SPACE"
    case groupChat = "GROUP_CHAT"
    case directMessage = "DIRECT_MESSAGE"
}

public struct ChatSpace: Codable, Hashable, Sendable, Identifiable {
    public var name: String
    public var displayName: String?
    public var spaceType: SpaceType?
    public var lastActiveTime: Date?

    public var id: String { name }
}

public struct SpacesPage: Codable, Sendable {
    public var spaces: [ChatSpace]
    public var nextPageToken: String?
}

public struct ChatSender: Codable, Hashable, Sendable {
    public var name: String?
    public var displayName: String?
    public var type: String?
}

public struct AttachmentDataRef: Codable, Hashable, Sendable {
    public var resourceName: String?
}

public struct ChatAttachment: Codable, Hashable, Sendable, Identifiable {
    public var name: String?
    public var contentName: String?
    public var contentType: String?
    public var attachmentDataRef: AttachmentDataRef?
    public var thumbnailUri: String?

    public var id: String { name ?? contentName ?? UUID().uuidString }
}

public struct Emoji: Codable, Hashable, Sendable {
    public var unicode: String?
}

public struct EmojiReactionSummary: Codable, Hashable, Sendable {
    public var emoji: Emoji?
    public var reactionCount: Int?
}

public struct ChatMessage: Codable, Hashable, Sendable, Identifiable {
    public var name: String
    public var sender: ChatSender?
    public var text: String?
    public var createTime: Date?
    public var attachment: [ChatAttachment]?
    public var emojiReactionSummaries: [EmojiReactionSummary]?

    public var id: String { name }
    public var attachments: [ChatAttachment]? { attachment }
}

public struct MessagesPage: Codable, Sendable {
    public var messages: [ChatMessage]
    public var nextPageToken: String?
}

public struct CreateMessageRequest: Codable, Sendable {
    public var text: String
    public init(text: String) { self.text = text }
}

public struct CreateReactionRequest: Encodable, Sendable {
    public var emoji: EmojiPayload
    public init(emojiUnicode: String) {
        self.emoji = EmojiPayload(unicode: emojiUnicode)
    }

    public struct EmojiPayload: Encodable, Sendable {
        public var unicode: String
    }
}

public struct SpaceReadState: Codable, Sendable {
    public var name: String?
    public var lastReadTime: Date?
}

public extension JSONDecoder {
    static var chat: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            let withFractional = ISO8601DateFormatter()
            withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = withFractional.date(from: dateString) {
                return date
            }
            let plain = ISO8601DateFormatter()
            plain.formatOptions = [.withInternetDateTime]
            if let date = plain.date(from: dateString) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid ISO8601 date: \(dateString)"
            )
        }
        d.keyDecodingStrategy = .useDefaultKeys
        return d
    }
}

public extension JSONEncoder {
    static var chat: JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }
}
