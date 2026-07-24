import Foundation

public struct ChatSpace: Codable, Hashable, Sendable {
    public let name: String
    public let displayName: String?
    public let type: String?
}

public struct ChatMessageSender: Codable, Hashable, Sendable {
    public let name: String?
    public let displayName: String?
    public let type: String?
}

public struct ChatMessage: Codable, Hashable, Sendable, Identifiable {
    public var id: String { name }

    public let name: String
    public let text: String?
    public let createTime: String?
    public let sender: ChatMessageSender?
}

public struct SpacesListResponse: Codable, Sendable {
    public let spaces: [ChatSpace]
    public let nextPageToken: String?
}

public struct MessagesListResponse: Codable, Sendable {
    public let messages: [ChatMessage]
    public let nextPageToken: String?
}

public enum ChatAPIParser {
    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        return decoder
    }()

    public static func decodeSpacesList(_ data: Data) throws -> SpacesListResponse {
        try decoder.decode(SpacesListResponse.self, from: data)
    }

    public static func decodeMessagesList(_ data: Data) throws -> MessagesListResponse {
        try decoder.decode(MessagesListResponse.self, from: data)
    }
}
