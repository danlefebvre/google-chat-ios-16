import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum ChatClientError: Error, Equatable {
    case invalidURL
    case httpStatus(Int)
    case decoding
}

public struct ChatClient: Sendable {
    private let baseURL: URL
    private let transport: any HTTPTransport
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    public init(baseURL: URL = URL(string: "https://chat.googleapis.com")!, transport: any HTTPTransport = URLSessionTransport()) {
        self.baseURL = baseURL
        self.transport = transport
        self.decoder = ChatJSON.makeDecoder()
        self.encoder = ChatJSON.makeEncoder()
    }

    public func listSpaces(accessToken: String, pageToken: String? = nil) async throws -> SpaceListResponse {
        guard var components = URLComponents(url: url(path: "v1/spaces"), resolvingAgainstBaseURL: false) else {
            throw ChatClientError.invalidURL
        }
        if let pageToken, !pageToken.isEmpty {
            components.queryItems = [URLQueryItem(name: "pageToken", value: pageToken)]
        }
        guard let url = components.url else { throw ChatClientError.invalidURL }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        return try await send(request)
    }

    public func listMessages(spaceName: String, accessToken: String, pageToken: String? = nil) async throws -> MessageListResponse {
        guard var components = URLComponents(url: url(path: "v1/\(spaceName)/messages"), resolvingAgainstBaseURL: false) else {
            throw ChatClientError.invalidURL
        }
        if let pageToken, !pageToken.isEmpty {
            components.queryItems = [URLQueryItem(name: "pageToken", value: pageToken)]
        }
        guard let url = components.url else { throw ChatClientError.invalidURL }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        return try await send(request)
    }

    public func sendMessage(spaceName: String, text: String, accessToken: String) async throws -> ChatMessage {
        var request = URLRequest(url: url(path: "v1/\(spaceName)/messages"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(["text": text])
        return try await send(request)
    }

    public func createReaction(messageName: String, emoji: String, accessToken: String) async throws -> Reaction {
        var request = URLRequest(url: url(path: "v1/\(messageName)/reactions"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let payload: [String: Any] = ["emoji": ["unicode": emoji]]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        return try await send(request)
    }

    public func markSpaceRead(spaceName: String, accessToken: String) async throws {
        // users.spaces.spaceReadState patch — write last read time to "now".
        var request = URLRequest(url: url(path: "v1/users/me/\(spaceName)/spaceReadState"))
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let formatter = ISO8601DateFormatter()
        let payload = ["lastReadTime": formatter.string(from: Date())]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (_, response) = try await transport.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw ChatClientError.httpStatus(code)
        }
    }

    public func uploadAttachment(
        spaceName: String,
        fileName: String,
        contentType: String,
        data: Data,
        accessToken: String
    ) async throws -> ChatAttachment {
        if AttachmentPolicy.shouldDownsample(byteCount: data.count, contentType: contentType),
           data.count > AttachmentPolicy.maxThumbnailBytes * 8 {
            // Callers should downsample before upload on device; still allow API path.
        }
        var components = URLComponents(url: url(path: "v1/media/\(spaceName)/attachments"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "uploadType", value: "multipart")]
        guard let endpoint = components.url else { throw ChatClientError.invalidURL }

        let boundary = "gcm-\(UUID().uuidString)"
        var body = Data()
        let metadata = "{\"filename\":\"\(fileName)\"}"
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/json; charset=UTF-8\r\n\r\n".data(using: .utf8)!)
        body.append(metadata.data(using: .utf8)!)
        body.append("\r\n--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(contentType)\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/related; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        return try await send(request)
    }

    public func downloadAttachment(attachmentName: String, accessToken: String) async throws -> Data {
        var request = URLRequest(url: url(path: "v1/media/\(attachmentName)"))
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await transport.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw ChatClientError.httpStatus(code)
        }
        return data
    }

    private func url(path: String) -> URL {
        URL(string: path, relativeTo: baseURL)!.absoluteURL
    }

    private func send<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await transport.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ChatClientError.httpStatus(-1)
        }
        guard (200..<300).contains(http.statusCode) else {
            throw ChatClientError.httpStatus(http.statusCode)
        }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw ChatClientError.decoding
        }
    }
}
