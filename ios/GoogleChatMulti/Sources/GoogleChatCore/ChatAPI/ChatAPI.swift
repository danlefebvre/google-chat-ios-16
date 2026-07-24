import Foundation

public struct SpacesListResponse: Codable, Sendable {
    public let spaces: [SpaceResource]?
    public let nextPageToken: String?
}

public struct SpaceResource: Codable, Sendable, Equatable {
    public let name: String
    public let displayName: String?
    public let type: String?
}

public struct MessagesListResponse: Codable, Sendable {
    public let messages: [MessageResource]?
    public let nextPageToken: String?
}

public struct MessageResource: Codable, Sendable, Equatable {
    public let name: String?
    public let text: String?
    public let createTime: String?
    public let sender: MessageSender?
}

public struct MessageSender: Codable, Sendable, Equatable {
    public let name: String?
    public let displayName: String?
}

public enum ChatAPIError: Error, Equatable {
    case unauthorized
    case httpStatus(Int)
    case decodingFailed
}

public protocol ChatAPIClient: Sendable {
    func listSpaces(pageToken: String?) async throws -> SpacesListResponse
    func listMessages(spaceName: String, pageToken: String?) async throws -> MessagesListResponse
    func sendMessage(spaceName: String, text: String) async throws -> MessageResource
}

public struct SpaceDTO: Sendable, Equatable {
    public let name: String
    public let displayName: String
    public let type: String?

    public init(name: String, displayName: String, type: String?) {
        self.name = name
        self.displayName = displayName
        self.type = type
    }
}

public enum ChatAPIParsing {
    public static func mapSpace(_ resource: SpaceResource) -> SpaceDTO {
        SpaceDTO(
            name: resource.name,
            displayName: resource.displayName ?? resource.name,
            type: resource.type
        )
    }

    public static func mapMessage(
        _ resource: MessageResource,
        spaceName: String,
        currentUserResourceName: String?
    ) -> ChatMessage? {
        guard let name = resource.name else { return nil }
        let senderName = resource.sender?.displayName ?? "Unknown"
        let isFromCurrentUser = resource.sender?.name == currentUserResourceName
        let createTime = ISO8601DateFormatter().date(from: resource.createTime ?? "") ?? Date.distantPast

        return ChatMessage(
            id: name,
            spaceName: spaceName,
            senderName: senderName,
            text: resource.text ?? "",
            createTime: createTime,
            isFromCurrentUser: isFromCurrentUser
        )
    }
}
