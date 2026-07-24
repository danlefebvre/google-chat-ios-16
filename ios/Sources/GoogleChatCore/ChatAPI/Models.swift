import Foundation

public enum SpaceType: String, Codable, Sendable {
    case space = "SPACE"
    case groupChat = "GROUP_CHAT"
    case directMessage = "DIRECT_MESSAGE"
}

public struct Space: Codable, Hashable, Sendable, Identifiable {
    public var id: String { name }
    public let name: String
    public let displayName: String?
    public let spaceType: SpaceType?

    public init(name: String, displayName: String? = nil, spaceType: SpaceType? = nil) {
        self.name = name
        self.displayName = displayName
        self.spaceType = spaceType
    }
}

public struct SpaceListResponse: Codable, Sendable {
    public let spaces: [Space]
    public let nextPageToken: String?

    public init(spaces: [Space], nextPageToken: String? = nil) {
        self.spaces = spaces
        self.nextPageToken = nextPageToken
    }
}

public struct ChatUser: Codable, Hashable, Sendable {
    public let name: String?
    public let displayName: String?

    public init(name: String? = nil, displayName: String? = nil) {
        self.name = name
        self.displayName = displayName
    }
}

public struct ChatAttachment: Codable, Hashable, Sendable, Identifiable {
    public var id: String { name }
    public let name: String
    public let contentName: String?
    public let contentType: String?
    public let downloadUri: String?
    public let thumbnailUri: String?

    public init(
        name: String,
        contentName: String? = nil,
        contentType: String? = nil,
        downloadUri: String? = nil,
        thumbnailUri: String? = nil
    ) {
        self.name = name
        self.contentName = contentName
        self.contentType = contentType
        self.downloadUri = downloadUri
        self.thumbnailUri = thumbnailUri
    }
}

/// Reference returned by `media.upload` / `spaces.attachments` upload.
public struct AttachmentDataRef: Codable, Hashable, Sendable {
    public let resourceName: String?
    public let attachmentUploadToken: String?

    public init(resourceName: String? = nil, attachmentUploadToken: String? = nil) {
        self.resourceName = resourceName
        self.attachmentUploadToken = attachmentUploadToken
    }
}

public struct UploadAttachmentResponse: Codable, Sendable {
    public let attachmentDataRef: AttachmentDataRef

    public init(attachmentDataRef: AttachmentDataRef) {
        self.attachmentDataRef = attachmentDataRef
    }
}

public struct ChatMessage: Codable, Hashable, Sendable, Identifiable {
    public var id: String { name }
    public let name: String
    public let sender: ChatUser?
    public let text: String?
    public let createTime: Date?
    public let attachments: [ChatAttachment]?

    enum CodingKeys: String, CodingKey {
        case name, sender, text, createTime
        case attachments = "attachment"
    }

    public init(
        name: String,
        sender: ChatUser? = nil,
        text: String? = nil,
        createTime: Date? = nil,
        attachments: [ChatAttachment]? = nil
    ) {
        self.name = name
        self.sender = sender
        self.text = text
        self.createTime = createTime
        self.attachments = attachments
    }
}

public struct MessageListResponse: Codable, Sendable {
    public let messages: [ChatMessage]
    public let nextPageToken: String?

    public init(messages: [ChatMessage], nextPageToken: String? = nil) {
        self.messages = messages
        self.nextPageToken = nextPageToken
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        messages = try container.decodeIfPresent([ChatMessage].self, forKey: .messages) ?? []
        nextPageToken = try container.decodeIfPresent(String.self, forKey: .nextPageToken)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(messages, forKey: .messages)
        try container.encodeIfPresent(nextPageToken, forKey: .nextPageToken)
    }

    private enum CodingKeys: String, CodingKey {
        case messages, nextPageToken
    }
}

public struct Emoji: Codable, Hashable, Sendable {
    public let unicode: String?

    public init(unicode: String? = nil) {
        self.unicode = unicode
    }
}

public struct Reaction: Codable, Hashable, Sendable, Identifiable {
    public var id: String { name }
    public let name: String
    public let emoji: Emoji

    public init(name: String, emoji: Emoji) {
        self.name = name
        self.emoji = emoji
    }
}
