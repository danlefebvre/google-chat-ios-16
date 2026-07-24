import Foundation

public enum ChatAPIError: Error, LocalizedError {
    case invalidURL
    case httpStatus(Int, Data?)
    case decoding(Error)

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid Chat API URL"
        case let .httpStatus(code, _):
            return "Chat API returned HTTP \(code)"
        case let .decoding(error):
            return "Failed to decode Chat API response: \(error.localizedDescription)"
        }
    }
}

public struct ChatAPIClient: Sendable {
    public let baseURL: URL
    public let session: URLSession

    public init(baseURL: URL = URL(string: "https://chat.googleapis.com/v1")!, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    public func listSpaces(accessToken: String, pageToken: String? = nil, pageSize: Int = 100) async throws -> ListSpacesResponse {
        var components = URLComponents(url: baseURL.appendingPathComponent("spaces"), resolvingAgainstBaseURL: false)
        var queryItems = [URLQueryItem(name: "pageSize", value: String(pageSize))]
        if let pageToken {
            queryItems.append(URLQueryItem(name: "pageToken", value: pageToken))
        }
        components?.queryItems = queryItems
        guard let url = components?.url else { throw ChatAPIError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        do {
            return try JSONDecoder.api.decode(ListSpacesResponse.self, from: data)
        } catch {
            throw ChatAPIError.decoding(error)
        }
    }

    public func listMessages(
        accessToken: String,
        spaceName: String,
        pageToken: String? = nil,
        pageSize: Int = 50
    ) async throws -> ListMessagesResponse {
        var components = URLComponents(
            url: baseURL.appendingPathComponent("\(spaceName)/messages"),
            resolvingAgainstBaseURL: false
        )
        var queryItems = [URLQueryItem(name: "pageSize", value: String(pageSize))]
        if let pageToken {
            queryItems.append(URLQueryItem(name: "pageToken", value: pageToken))
        }
        components?.queryItems = queryItems
        guard let url = components?.url else { throw ChatAPIError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        do {
            return try JSONDecoder.api.decode(ListMessagesResponse.self, from: data)
        } catch {
            throw ChatAPIError.decoding(error)
        }
    }

    public func createMessage(accessToken: String, spaceName: String, text: String) async throws -> ChatMessage {
        guard let url = URL(string: baseURL.absoluteString + "/\(spaceName)/messages") else {
            throw ChatAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try MessageComposer.createTextMessageBody(text: text)

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        do {
            return try JSONDecoder.api.decode(ChatMessage.self, from: data)
        } catch {
            throw ChatAPIError.decoding(error)
        }
    }

    public func markSpaceRead(accessToken: String, spaceName: String, readTime: Date = Date()) async throws {
        guard let url = URL(string: baseURL.absoluteString + "/\(spaceName)/spaceReadState") else {
            throw ChatAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let payload = ["lastReadTime": formatter.string(from: readTime)]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
    }

    func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200 ... 299).contains(http.statusCode) else {
            throw ChatAPIError.httpStatus(http.statusCode, data)
        }
    }
}
