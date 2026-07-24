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
    private static let iso8601Fractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    public static func parseCreateTime(_ value: String?) -> Date {
        guard let value, !value.isEmpty else { return .distantPast }
        return iso8601Fractional.date(from: value)
            ?? iso8601.date(from: value)
            ?? .distantPast
    }

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
        let createTime = parseCreateTime(resource.createTime)

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
