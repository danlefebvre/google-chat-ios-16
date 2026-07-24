import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public protocol TokenProviding: Sendable {
    func accessToken(for accountId: AccountID) async throws -> String
}

public enum ChatAPIError: Error, Equatable {
    case invalidURL
    case httpStatus(Int)
    case decodingFailed
    case emptyBody
}

public actor ChatAPIClient {
    private let baseURL: URL
    private let session: URLSession
    private let tokens: any TokenProviding

    public init(
        tokens: any TokenProviding,
        session: URLSession = .shared,
        baseURL: URL = URL(string: "https://chat.googleapis.com/v1")!
    ) {
        self.tokens = tokens
        self.session = session
        self.baseURL = baseURL
    }

    public func listSpaces(
        accountId: AccountID,
        pageSize: Int = 100,
        pageToken: String? = nil
    ) async throws -> SpaceListResponse {
        var components = URLComponents(
            url: baseURL.appendingPathComponent("spaces"),
            resolvingAgainstBaseURL: false
        )!
        var items = [URLQueryItem(name: "pageSize", value: String(pageSize))]
        if let pageToken { items.append(URLQueryItem(name: "pageToken", value: pageToken)) }
        components.queryItems = items
        guard let url = components.url else { throw ChatAPIError.invalidURL }
        return try await get(url, accountId: accountId)
    }

    public func listMessages(
        accountId: AccountID,
        spaceName: String,
        pageSize: Int = 50,
        pageToken: String? = nil
    ) async throws -> MessageListResponse {
        var components = URLComponents(
            url: baseURL.appendingPathComponent("\(spaceName)/messages"),
            resolvingAgainstBaseURL: false
        )!
        var items = [
            URLQueryItem(name: "pageSize", value: String(pageSize)),
            URLQueryItem(name: "orderBy", value: "createTime desc"),
        ]
        if let pageToken { items.append(URLQueryItem(name: "pageToken", value: pageToken)) }
        components.queryItems = items
        guard let url = components.url else { throw ChatAPIError.invalidURL }
        return try await get(url, accountId: accountId)
    }

    public func sendMessage(
        accountId: AccountID,
        spaceName: String,
        text: String
    ) async throws -> ChatMessage {
        let url = baseURL.appendingPathComponent("\(spaceName)/messages")
        return try await post(url, accountId: accountId, body: CreateMessageRequest(text: text))
    }

    public func addReaction(
        accountId: AccountID,
        messageName: String,
        unicode: String
    ) async throws {
        let url = baseURL.appendingPathComponent("\(messageName)/reactions")
        let _: EmptyResponse = try await post(
            url,
            accountId: accountId,
            body: CreateReactionRequest(unicode: unicode)
        )
    }

    /// Upload media bytes then attach via a follow-up message (Chat media API).
    public func uploadAttachment(
        accountId: AccountID,
        spaceName: String,
        filename: String,
        mimeType: String,
        data: Data
    ) async throws -> ChatAttachment {
        // Google Chat media upload uses multipart / upload endpoints; keep a
        // thin wrapper so the UI can call one method with memory-limited data.
        let boundary = "gcm-\(UUID().uuidString)"
        var body = Data()
        func append(_ string: String) {
            if let chunk = string.data(using: .utf8) { body.append(chunk) }
        }
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"metadata\"\r\n")
        append("Content-Type: application/json; charset=UTF-8\r\n\r\n")
        append("{\"filename\":\(jsonString(filename)),\"mimeType\":\(jsonString(mimeType))}\r\n")
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"media\"; filename=\"\(filename)\"\r\n")
        append("Content-Type: \(mimeType)\r\n\r\n")
        body.append(data)
        append("\r\n--\(boundary)--\r\n")

        var components = URLComponents(
            url: baseURL.appendingPathComponent("media/\(spaceName)/attachments"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [URLQueryItem(name: "uploadType", value: "multipart")]
        guard let url = components.url else { throw ChatAPIError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(
            "multipart/related; boundary=\(boundary)",
            forHTTPHeaderField: "Content-Type"
        )
        request.httpBody = body
        try await authorize(&request, accountId: accountId)
        return try await send(request)
    }

    public func markSpaceRead(
        accountId: AccountID,
        spaceName: String,
        lastReadTime: Date = Date()
    ) async throws {
        // users.spaces.spaceReadState patch
        let path = "users/me/spaces/\(spaceName.replacingOccurrences(of: "spaces/", with: ""))/spaceReadState"
        let url = baseURL.appendingPathComponent(path)
        struct Body: Encodable { let lastReadTime: Date }
        let _: EmptyResponse = try await patch(
            url,
            accountId: accountId,
            body: Body(lastReadTime: lastReadTime),
            query: [URLQueryItem(name: "updateMask", value: "lastReadTime")]
        )
    }

    private struct EmptyResponse: Decodable {}

    private func get<T: Decodable>(_ url: URL, accountId: AccountID) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        try await authorize(&request, accountId: accountId)
        return try await send(request)
    }

    private func post<Body: Encodable, T: Decodable>(
        _ url: URL,
        accountId: AccountID,
        body: Body
    ) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder.chat.encode(body)
        try await authorize(&request, accountId: accountId)
        return try await send(request)
    }

    private func patch<Body: Encodable, T: Decodable>(
        _ url: URL,
        accountId: AccountID,
        body: Body,
        query: [URLQueryItem]
    ) async throws -> T {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = query
        guard let finalURL = components.url else { throw ChatAPIError.invalidURL }
        var request = URLRequest(url: finalURL)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder.chat.encode(body)
        try await authorize(&request, accountId: accountId)
        return try await send(request)
    }

    private func authorize(_ request: inout URLRequest, accountId: AccountID) async throws {
        let token = try await tokens.accessToken(for: accountId)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }

    private func send<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await session.dataCompat(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard (200..<300).contains(status) else {
            throw ChatAPIError.httpStatus(status)
        }
        if T.self == EmptyResponse.self {
            return EmptyResponse() as! T
        }
        guard !data.isEmpty else { throw ChatAPIError.emptyBody }
        do {
            return try JSONDecoder.chat.decode(T.self, from: data)
        } catch {
            throw ChatAPIError.decodingFailed
        }
    }
}

private func jsonString(_ value: String) -> String {
    let data = try? JSONSerialization.data(withJSONObject: value, options: [.fragmentsAllowed])
    return data.flatMap { String(data: $0, encoding: .utf8) } ?? "\"\""
}

private extension URLSession {
    func dataCompat(for request: URLRequest) async throws -> (Data, URLResponse) {
        #if canImport(FoundationNetworking)
        try await withCheckedThrowingContinuation { continuation in
            let task = dataTask(with: request) { data, response, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let data, let response else {
                    continuation.resume(throwing: URLError(.badServerResponse))
                    return
                }
                continuation.resume(returning: (data, response))
            }
            task.resume()
        }
        #else
        try await data(for: request)
        #endif
    }
}
