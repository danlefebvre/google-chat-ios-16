import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum ChatAPIError: Error, Equatable {
    case httpStatus(Int, String)
    case decoding(String)
    case unauthorized
}

public protocol HTTPTransport: AnyObject {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

#if os(Linux)
/// URLSession async bridging for Swift on Linux.
public final class URLSessionTransport: HTTPTransport, @unchecked Sendable {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await withCheckedThrowingContinuation { cont in
            let task = session.dataTask(with: request) { data, response, error in
                if let error {
                    cont.resume(throwing: error)
                    return
                }
                guard let response else {
                    cont.resume(throwing: URLError(.badServerResponse))
                    return
                }
                cont.resume(returning: (data ?? Data(), response))
            }
            task.resume()
        }
    }
}
#else
public final class URLSessionTransport: HTTPTransport, @unchecked Sendable {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await session.data(for: request)
    }
}
#endif

/// Thin REST wrappers around Google Chat API.
public struct ChatClient {
    public var baseURL: URL
    public var transport: HTTPTransport

    public init(
        baseURL: URL = URL(string: "https://chat.googleapis.com/v1/")!,
        transport: HTTPTransport = URLSessionTransport()
    ) {
        self.baseURL = baseURL
        self.transport = transport
    }

    public func listSpaces(accessToken: String, pageToken: String? = nil) async throws -> SpacesPage {
        var components = URLComponents(url: baseURL.appendingPathComponent("spaces"), resolvingAgainstBaseURL: false)!
        var items = [URLQueryItem(name: "pageSize", value: "100")]
        if let pageToken { items.append(URLQueryItem(name: "pageToken", value: pageToken)) }
        components.queryItems = items
        return try await get(components.url!, accessToken: accessToken)
    }

    public func listMessages(
        accessToken: String,
        spaceName: String,
        pageToken: String? = nil,
        pageSize: Int = 50
    ) async throws -> MessagesPage {
        var components = URLComponents(
            url: baseURL.appendingPathComponent("\(spaceName)/messages"),
            resolvingAgainstBaseURL: false
        )!
        var items = [URLQueryItem(name: "pageSize", value: String(pageSize))]
        if let pageToken { items.append(URLQueryItem(name: "pageToken", value: pageToken)) }
        components.queryItems = items
        return try await get(components.url!, accessToken: accessToken)
    }

    public func sendMessage(
        accessToken: String,
        spaceName: String,
        text: String
    ) async throws -> ChatMessage {
        let url = baseURL.appendingPathComponent("\(spaceName)/messages")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder.chat.encode(CreateMessageRequest(text: text))
        return try await send(request)
    }

    public func createReaction(
        accessToken: String,
        messageName: String,
        emojiUnicode: String
    ) async throws {
        let url = baseURL.appendingPathComponent("\(messageName)/reactions")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder.chat.encode(CreateReactionRequest(emojiUnicode: emojiUnicode))
        try await sendVoid(request)
    }

    public func markSpaceRead(
        accessToken: String,
        spaceName: String,
        at date: Date = Date()
    ) async throws {
        // users.spaces.spaceReadState patch
        let url = baseURL.appendingPathComponent("users/me/\(spaceName)/spaceReadState")
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "updateMask", value: "lastReadTime")]
        request.url = components.url
        let body = SpaceReadState(name: nil, lastReadTime: date)
        request.httpBody = try JSONEncoder.chat.encode(body)
        try await sendVoid(request)
    }

    public func downloadMedia(
        accessToken: String,
        resourceName: String
    ) async throws -> Data {
        let url = baseURL.appendingPathComponent("media/\(resourceName)")
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await transport.data(for: request)
        try validate(response, data: data)
        return data
    }

    /// Upload attachment bytes via Chat media API (caller enforces AttachmentPolicy limits).
    public func uploadMedia(
        accessToken: String,
        spaceName: String,
        filename: String,
        contentType: String,
        bytes: Data
    ) async throws -> ChatMessage {
        guard AttachmentPolicy.allowsUpload(byteCount: bytes.count) else {
            throw ChatAPIError.httpStatus(413, "attachment too large")
        }
        // Multipart upload against spaces.messages.create with attachment metadata.
        // For MVP we send a message referencing uploaded media through the media endpoint.
        let boundary = "gcm-\(UUID().uuidString)"
        let url = baseURL.appendingPathComponent("media/\(spaceName)/attachments:upload")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/related; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        let meta = "{\"filename\":\"\(filename)\",\"contentType\":\"\(contentType)\"}"
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/json; charset=UTF-8\r\n\r\n".data(using: .utf8)!)
        body.append(meta.data(using: .utf8)!)
        body.append("\r\n--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(contentType)\r\n\r\n".data(using: .utf8)!)
        body.append(bytes)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        // After media upload, create a follow-up message referencing the file name.
        try await sendVoid(request)
        return try await sendMessage(accessToken: accessToken, spaceName: spaceName, text: "Attachment: \(filename)")
    }

    private func get<T: Decodable>(_ url: URL, accessToken: String) async throws -> T {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        return try await send(request)
    }

    private func send<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await transport.data(for: request)
        try validate(response, data: data)
        do {
            return try JSONDecoder.chat.decode(T.self, from: data)
        } catch {
            throw ChatAPIError.decoding(String(describing: error))
        }
    }

    private func sendVoid(_ request: URLRequest) async throws {
        let (data, response) = try await transport.data(for: request)
        try validate(response, data: data)
    }

    private func validate(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        if http.statusCode == 401 { throw ChatAPIError.unauthorized }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw ChatAPIError.httpStatus(http.statusCode, body)
        }
    }
}
