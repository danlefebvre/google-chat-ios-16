import Foundation

public struct ChatSpace: Codable, Hashable, Sendable, Identifiable {
    public var id: String { name }
    public let name: String
    public let displayName: String?
    public let spaceType: String?
    public let spaceHistoryState: String?

    public init(
        name: String,
        displayName: String? = nil,
        spaceType: String? = nil,
        spaceHistoryState: String? = nil
    ) {
        self.name = name
        self.displayName = displayName
        self.spaceType = spaceType
        self.spaceHistoryState = spaceHistoryState
    }
}

public struct ChatUser: Codable, Hashable, Sendable {
    public let name: String?
    public let displayName: String?
    public let type: String?
}

public struct ChatMessage: Codable, Hashable, Sendable, Identifiable {
    public var id: String { name }
    public let name: String
    public let text: String?
    public let createTime: String?
    public let sender: ChatUser?
    public let attachment: [ChatAttachment]?

    public init(
        name: String,
        text: String? = nil,
        createTime: String? = nil,
        sender: ChatUser? = nil,
        attachment: [ChatAttachment]? = nil
    ) {
        self.name = name
        self.text = text
        self.createTime = createTime
        self.sender = sender
        self.attachment = attachment
    }
}

public struct ChatAttachment: Codable, Hashable, Sendable {
    public let name: String?
    public let contentName: String?
    public let downloadUri: String?
    public let thumbnailUri: String?
}

public struct ListSpacesResponse: Codable, Sendable {
    public let spaces: [ChatSpace]
    public let nextPageToken: String?
}

public struct ListMessagesResponse: Codable, Sendable {
    public let messages: [ChatMessage]
    public let nextPageToken: String?
}

public extension JSONDecoder {
    static let api: JSONDecoder = {
        JSONDecoder()
    }()
}

public extension JSONEncoder {
    static let api: JSONEncoder = {
        JSONEncoder()
    }()
}
