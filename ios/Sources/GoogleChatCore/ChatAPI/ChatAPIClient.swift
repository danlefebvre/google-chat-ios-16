import Foundation

public struct ChatAPIConfiguration: Sendable {
    public let baseURL: URL

    public init(baseURL: URL = URL(string: "https://chat.googleapis.com/v1")!) {
        self.baseURL = baseURL
    }
}

public enum ChatAPIError: Error {
    case invalidResponse
    case httpStatus(Int)
}

public final class ChatAPIClient: @unchecked Sendable {
    private let config: ChatAPIConfiguration
    private let session: URLSession

    public init(config: ChatAPIConfiguration = ChatAPIConfiguration(), session: URLSession = .shared) {
        self.config = config
        self.session = session
    }

    public func listSpaces(accessToken: String, pageToken: String? = nil) async throws -> SpacesListResponse {
        var components = URLComponents(
            url: config.baseURL.appendingPathComponent("spaces"),
            resolvingAgainstBaseURL: false
        )!
        var query: [URLQueryItem] = [URLQueryItem(name: "pageSize", value: "50")]
        if let pageToken {
            query.append(URLQueryItem(name: "pageToken", value: pageToken))
        }
        components.queryItems = query

        let request = authorizedRequest(url: components.url!, accessToken: accessToken)
        let (data, response) = try await session.data(for: request)
        try validate(response)
        return try ChatAPIParser.decodeSpacesList(data)
    }

    public func listMessages(
        spaceResourceName: String,
        accessToken: String,
        pageToken: String? = nil
    ) async throws -> MessagesListResponse {
        var components = URLComponents(
            url: config.baseURL.appendingPathComponent("\(spaceResourceName)/messages"),
            resolvingAgainstBaseURL: false
        )!
        var query: [URLQueryItem] = [URLQueryItem(name: "pageSize", value: "50")]
        if let pageToken {
            query.append(URLQueryItem(name: "pageToken", value: pageToken))
        }
        components.queryItems = query

        let request = authorizedRequest(url: components.url!, accessToken: accessToken)
        let (data, response) = try await session.data(for: request)
        try validate(response)
        return try ChatAPIParser.decodeMessagesList(data)
    }

    public func sendMessage(spaceResourceName: String, text: String, accessToken: String) async throws -> ChatMessage {
        let url = config.baseURL.appendingPathComponent("\(spaceResourceName)/messages")
        var request = authorizedRequest(url: url, accessToken: accessToken, method: "POST")
        let body = ["text": text]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await session.data(for: request)
        try validate(response)
        return try JSONDecoder().decode(ChatMessage.self, from: data)
    }

    public func markSpaceRead(spaceResourceName: String, accessToken: String) async throws {
        let url = config.baseURL.appendingPathComponent("users/me/spaces/\(spaceResourceName)/spaceReadState")
        var request = authorizedRequest(url: url, accessToken: accessToken, method: "PATCH")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["lastReadTime": ISO8601DateFormatter().string(from: Date())])
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (_, response) = try await session.data(for: request)
        try validate(response)
    }

    public func addReaction(messageName: String, emoji: String, accessToken: String) async throws {
        let url = config.baseURL.appendingPathComponent("\(messageName)/reactions")
        var request = authorizedRequest(url: url, accessToken: accessToken, method: "POST")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["emoji": ["unicode": emoji]])
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let (_, response) = try await session.data(for: request)
        try validate(response)
    }

    public func downloadAttachment(resourceName: String, accessToken: String) async throws -> Data {
        let url = config.baseURL.appendingPathComponent(resourceName)
        let request = authorizedRequest(url: url, accessToken: accessToken)
        let (data, response) = try await session.data(for: request)
        try validate(response)
        return data
    }

    private func authorizedRequest(url: URL, accessToken: String, method: String = "GET") -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        return request
    }

    private func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw ChatAPIError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            throw ChatAPIError.httpStatus(http.statusCode)
        }
    }
}
