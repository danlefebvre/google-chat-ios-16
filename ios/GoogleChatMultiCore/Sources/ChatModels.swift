import Foundation

public extension JSONDecoder {
    static let chat: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

public extension JSONEncoder {
    static let chat: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
}

public struct SpaceListResponse: Codable, Sendable {
    public var spaces: [ChatSpace]
    public var nextPageToken: String?

    public init(spaces: [ChatSpace], nextPageToken: String? = nil) {
        self.spaces = spaces
        self.nextPageToken = nextPageToken
    }
}

public struct ChatSpace: Codable, Hashable, Sendable {
    public var name: String
    public var displayName: String?
    public var spaceType: String?
    public var lastActiveTime: Date?

    public init(
        name: String,
        displayName: String? = nil,
        spaceType: String? = nil,
        lastActiveTime: Date? = nil
    ) {
        self.name = name
        self.displayName = displayName
        self.spaceType = spaceType
        self.lastActiveTime = lastActiveTime
    }

    public var isDirectMessage: Bool {
        spaceType == "DIRECT_MESSAGE"
    }

    public var resolvedTitle: String {
        let trimmed = displayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmed.isEmpty { return trimmed }
        return isDirectMessage ? "DM" : name
    }
}

public struct MessageListResponse: Codable, Sendable {
    public var messages: [ChatMessage]
    public var nextPageToken: String?

    public init(messages: [ChatMessage], nextPageToken: String? = nil) {
        self.messages = messages
        self.nextPageToken = nextPageToken
    }
}

public struct ChatMessage: Codable, Hashable, Identifiable, Sendable {
    public var name: String
    public var text: String?
    public var createTime: Date?
    public var sender: ChatSender?
    public var attachment: [ChatAttachment]?
    public var emojiReactionSummaries: [EmojiReactionSummary]?

    public var id: String { name }

    public init(
        name: String,
        text: String? = nil,
        createTime: Date? = nil,
        sender: ChatSender? = nil,
        attachment: [ChatAttachment]? = nil,
        emojiReactionSummaries: [EmojiReactionSummary]? = nil
    ) {
        self.name = name
        self.text = text
        self.createTime = createTime
        self.sender = sender
        self.attachment = attachment
        self.emojiReactionSummaries = emojiReactionSummaries
    }
}

public struct ChatSender: Codable, Hashable, Sendable {
    public var name: String?
    public var displayName: String?

    public init(name: String? = nil, displayName: String? = nil) {
        self.name = name
        self.displayName = displayName
    }
}

public struct ChatAttachment: Codable, Hashable, Sendable {
    public var name: String?
    public var contentName: String?
    public var contentType: String?
    public var downloadUri: String?
    public var thumbnailUri: String?
    public var source: String?

    public init(
        name: String? = nil,
        contentName: String? = nil,
        contentType: String? = nil,
        downloadUri: String? = nil,
        thumbnailUri: String? = nil,
        source: String? = nil
    ) {
        self.name = name
        self.contentName = contentName
        self.contentType = contentType
        self.downloadUri = downloadUri
        self.thumbnailUri = thumbnailUri
        self.source = source
    }
}

public struct EmojiReactionSummary: Codable, Hashable, Sendable {
    public var emoji: ChatEmoji?
    public var reactionCount: Int?

    public init(emoji: ChatEmoji? = nil, reactionCount: Int? = nil) {
        self.emoji = emoji
        self.reactionCount = reactionCount
    }
}

public struct ChatEmoji: Codable, Hashable, Sendable {
    public var unicode: String?

    public init(unicode: String? = nil) {
        self.unicode = unicode
    }
}

public struct CreateMessageRequest: Codable, Sendable {
    public var text: String

    public init(text: String) {
        self.text = text
    }
}

public struct CreateReactionRequest: Codable, Sendable {
    public var emoji: ChatEmoji

    public init(unicode: String) {
        self.emoji = ChatEmoji(unicode: unicode)
    }
}
