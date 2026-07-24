import Foundation

public struct ChatSpace: Codable, Sendable, Equatable {
    public let name: String
    public var displayName: String
    public var type: SpaceType

    public init(name: String, displayName: String, type: SpaceType = .space) {
        self.name = name
        self.displayName = displayName
        self.type = type
    }
}

public enum SpaceType: String, Codable, Sendable {
    case space
    case directMessage = "DIRECT_MESSAGE"
}

public struct ChatMessage: Codable, Sendable, Equatable, Identifiable {
    public var id: String { name }
    public let name: String
    public let spaceName: String
    public var text: String
    public var senderDisplayName: String
    public var createTime: Date

    public init(
        name: String,
        spaceName: String,
        text: String,
        senderDisplayName: String,
        createTime: Date
    ) {
        self.name = name
        self.spaceName = spaceName
        self.text = text
        self.senderDisplayName = senderDisplayName
        self.createTime = createTime
    }
}

public struct Reaction: Codable, Sendable, Equatable {
    public let emoji: String
    public let userName: String

    public init(emoji: String, userName: String) {
        self.emoji = emoji
        self.userName = userName
    }
}

public struct AttachmentRef: Codable, Sendable, Equatable, Identifiable {
    public var id: String { name }
    public let name: String
    public let contentName: String
    public let downloadUri: URL?
    public let thumbnailUri: URL?

    public init(
        name: String,
        contentName: String,
        downloadUri: URL?,
        thumbnailUri: URL?
    ) {
        self.name = name
        self.contentName = contentName
        self.downloadUri = downloadUri
        self.thumbnailUri = thumbnailUri
    }
}
