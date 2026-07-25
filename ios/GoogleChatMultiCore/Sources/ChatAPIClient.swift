import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public protocol TokenProviding: Sendable {
    func accessToken(for accountId: AccountID) async throws -> String
    /// Drop any cached access token so the next `accessToken` call refreshes.
    func invalidateAccessToken(for accountId: AccountID) async
}

public enum ChatAPIError: Error, Equatable, LocalizedError {
    case invalidURL
    case httpStatus(Int)
    case decodingFailed
    case emptyBody

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL while calling Google Chat API."
        case let .httpStatus(code):
            if code < 0 {
                return "Network request failed (no HTTP response)."
            }
            return "Google Chat API HTTP \(code)."
        case .decodingFailed:
            return "Could not decode Google Chat API response."
        case .emptyBody:
            return "Google Chat API returned an empty body."
        }
    }
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
        var items = [URLQueryItem(name: "pageSize", value: String(pageSize))]
        if let pageToken { items.append(URLQueryItem(name: "pageToken", value: pageToken)) }
        let url = try makeURL(path: "spaces", queryItems: items)
        return try await get(url, accountId: accountId)
    }

    public func listMessages(
        accountId: AccountID,
        spaceName: String,
        pageSize: Int = 50,
        pageToken: String? = nil
    ) async throws -> MessageListResponse {
        var items = [
            URLQueryItem(name: "pageSize", value: String(pageSize)),
            URLQueryItem(name: "orderBy", value: "createTime desc"),
        ]
        if let pageToken { items.append(URLQueryItem(name: "pageToken", value: pageToken)) }
        let url = try makeURL(path: "\(spaceName)/messages", queryItems: items)
        return try await get(url, accountId: accountId)
    }

    /// Lists space members (used to resolve DM titles / missing sender display names).
    public func listMembers(
        accountId: AccountID,
        spaceName: String,
        pageSize: Int = 100,
        showInvited: Bool = false
    ) async throws -> MembershipListResponse {
        let url = try makeURL(
            path: "\(spaceName)/members",
            queryItems: [
                URLQueryItem(name: "pageSize", value: String(pageSize)),
                URLQueryItem(name: "showInvited", value: showInvited ? "true" : "false"),
            ]
        )
        return try await get(url, accountId: accountId)
    }

    public func sendMessage(
        accountId: AccountID,
        spaceName: String,
        text: String,
        attachmentUploadTokens: [String] = []
    ) async throws -> ChatMessage {
        let url = try makeURL(path: "\(spaceName)/messages")
        let attachments = attachmentUploadTokens.isEmpty
            ? nil
            : attachmentUploadTokens.map(CreateMessageAttachment.init(uploadToken:))
        return try await post(
            url,
            accountId: accountId,
            body: CreateMessageRequest(text: text, attachment: attachments)
        )
    }

    public func addReaction(
        accountId: AccountID,
        messageName: String,
        unicode: String
    ) async throws {
        let url = try makeURL(path: "\(messageName)/reactions")
        let _: EmptyResponse = try await post(
            url,
            accountId: accountId,
            body: CreateReactionRequest(unicode: unicode)
        )
    }

    /// Upload media bytes via the Chat upload endpoint; returns an upload token
    /// for `CreateMessageRequest.attachment`.
    public func uploadAttachment(
        accountId: AccountID,
        spaceName: String,
        filename: String,
        mimeType: String,
        data: Data
    ) async throws -> AttachmentUploadResponse {
        let boundary = "gcm-\(UUID().uuidString)"
        var body = Data()
        func append(_ string: String) {
            if let chunk = string.data(using: .utf8) { body.append(chunk) }
        }
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"metadata\"\r\n")
        append("Content-Type: application/json; charset=UTF-8\r\n\r\n")
        append("{\"filename\":\(jsonString(filename))}\r\n")
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"media\"; filename=\"\(filename)\"\r\n")
        append("Content-Type: \(mimeType)\r\n\r\n")
        body.append(data)
        append("\r\n--\(boundary)--\r\n")

        // Chat media upload host: https://chat.googleapis.com/upload/v1/{parent}/attachments
        var components = URLComponents(
            string: "https://chat.googleapis.com/upload/v1/\(spaceName)/attachments"
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
        return try await send(request, accountId: accountId)
    }

    public func getSpaceReadState(
        accountId: AccountID,
        spaceName: String
    ) async throws -> SpaceReadState {
        let url = try spaceReadStateURL(spaceName: spaceName)
        return try await get(url, accountId: accountId)
    }

    public func markSpaceRead(
        accountId: AccountID,
        spaceName: String,
        lastReadTime: Date = Date()
    ) async throws {
        let url = try spaceReadStateURL(spaceName: spaceName)
        struct Body: Encodable { let lastReadTime: Date }
        let _: EmptyResponse = try await patch(
            url,
            accountId: accountId,
            body: Body(lastReadTime: lastReadTime),
            query: [URLQueryItem(name: "updateMask", value: "lastReadTime")]
        )
    }

    private func spaceReadStateURL(spaceName: String) throws -> URL {
        let spaceId = spaceName.replacingOccurrences(of: "spaces/", with: "")
        return try makeURL(path: "users/me/spaces/\(spaceId)/spaceReadState")
    }

    /// Builds API URLs without percent-encoding `/` inside resource names
    /// (`spaces/AAA/messages`). `URL.appendingPathComponent` would turn those
    /// into `spaces%2FAAA%2Fmessages` and break Chat REST paths.
    private func makeURL(path: String, queryItems: [URLQueryItem] = []) throws -> URL {
        let trimmed = path.hasPrefix("/") ? String(path.dropFirst()) : path
        guard var components = URLComponents(string: "\(baseURL.absoluteString)/\(trimmed)") else {
            throw ChatAPIError.invalidURL
        }
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        guard let url = components.url else { throw ChatAPIError.invalidURL }
        return url
    }

    private struct EmptyResponse: Decodable {}

    private func get<T: Decodable>(_ url: URL, accountId: AccountID) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        try await authorize(&request, accountId: accountId)
        return try await send(request, accountId: accountId)
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
        return try await send(request, accountId: accountId)
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
        return try await send(request, accountId: accountId)
    }

    private func authorize(_ request: inout URLRequest, accountId: AccountID) async throws {
        let token = try await tokens.accessToken(for: accountId)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }

    private func send<T: Decodable>(
        _ request: URLRequest,
        accountId: AccountID,
        allowRetry: Bool = true
    ) async throws -> T {
        let (data, response) = try await session.dataCompat(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        if status == 401, allowRetry {
            // Access tokens expire ~1h; refresh once and retry the same request.
            await tokens.invalidateAccessToken(for: accountId)
            var retry = request
            try await authorize(&retry, accountId: accountId)
            return try await send(retry, accountId: accountId, allowRetry: false)
        }
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
