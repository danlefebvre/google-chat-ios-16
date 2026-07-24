import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct ChatAPIClient: Sendable {
    public var baseURL: URL
    public var session: URLSession
    public var accessTokenProvider: @Sendable () async throws -> String

    public init(
        baseURL: URL = URL(string: "https://chat.googleapis.com")!,
        session: URLSession = .shared,
        accessTokenProvider: @escaping @Sendable () async throws -> String
    ) {
        self.baseURL = baseURL
        self.session = session
        self.accessTokenProvider = accessTokenProvider
    }

    public func listSpaces(pageToken: String?, pageSize: Int) async throws -> SpacesPage {
        var items: [URLQueryItem] = [URLQueryItem(name: "pageSize", value: String(pageSize))]
        if let pageToken, !pageToken.isEmpty {
            items.append(URLQueryItem(name: "pageToken", value: pageToken))
        }
        let data = try await get(path: "v1/spaces", query: items)
        let decoded = try JSONDecoder().decode(SpacesResponseDTO.self, from: data)
        return SpacesPage(
            spaces: (decoded.spaces ?? []).map {
                ChatSpace(name: $0.name, displayName: $0.displayName ?? "", spaceType: $0.spaceType ?? "SPACE")
            },
            nextPageToken: decoded.nextPageToken
        )
    }

    public func listMessages(spaceName: String, pageToken: String?, pageSize: Int) async throws -> MessagesPage {
        var items: [URLQueryItem] = [
            URLQueryItem(name: "pageSize", value: String(pageSize)),
            URLQueryItem(name: "orderBy", value: "createTime desc"),
        ]
        if let pageToken, !pageToken.isEmpty {
            items.append(URLQueryItem(name: "pageToken", value: pageToken))
        }
        let data = try await get(path: "v1/\(spaceName)/messages", query: items)
        let decoded = try JSONDecoder.chat.decode(MessagesResponseDTO.self, from: data)
        let messages = (decoded.messages ?? []).map { dto -> ChatMessage in
            ChatMessage(
                name: dto.name,
                spaceName: spaceName,
                accountID: AccountID(issuer: "", subject: ""),
                text: dto.text ?? "",
                senderDisplayName: dto.sender?.displayName ?? "Someone",
                createTime: dto.createTime ?? Date.distantPast,
                attachmentResourceNames: (dto.attachment ?? []).compactMap(\.name)
            )
        }
        return MessagesPage(messages: messages, nextPageToken: decoded.nextPageToken)
    }

    public func sendMessage(spaceName: String, text: String) async throws -> ChatMessage {
        let body = try JSONSerialization.data(withJSONObject: ["text": text])
        let data = try await send(path: "v1/\(spaceName)/messages", method: "POST", body: body)
        let dto = try JSONDecoder.chat.decode(MessageDTO.self, from: data)
        return ChatMessage(
            name: dto.name,
            spaceName: spaceName,
            accountID: AccountID(issuer: "", subject: ""),
            text: dto.text ?? text,
            senderDisplayName: dto.sender?.displayName ?? "You",
            createTime: dto.createTime ?? Date(),
            attachmentResourceNames: (dto.attachment ?? []).compactMap(\.name)
        )
    }

    public func createReaction(messageName: String, emoji: String) async throws -> String {
        let body = try JSONSerialization.data(withJSONObject: [
            "emoji": ["unicode": emoji],
        ])
        let data = try await send(path: "v1/\(messageName)/reactions", method: "POST", body: body)
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return (obj?["name"] as? String) ?? ""
    }

    public func markSpaceRead(spaceName: String, readTime: Date = Date()) async throws {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let body = try JSONSerialization.data(withJSONObject: [
            "lastReadTime": formatter.string(from: readTime),
        ])
        _ = try await send(
            path: "v1/users/me/\(spaceName)/spaceReadState",
            method: "PATCH",
            body: body,
            query: [URLQueryItem(name: "updateMask", value: "lastReadTime")]
        )
    }

    private func get(path: String, query: [URLQueryItem] = []) async throws -> Data {
        try await send(path: path, method: "GET", body: nil, query: query)
    }

    private func makeURL(path: String, query: [URLQueryItem]) throws -> URL {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw ChatAPIError.invalidResponse
        }
        let basePath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let trimmed = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        components.path = "/" + [basePath, trimmed].filter { !$0.isEmpty }.joined(separator: "/")
        components.queryItems = query.isEmpty ? nil : query
        guard let url = components.url else { throw ChatAPIError.invalidResponse }
        return url
    }

    private func send(path: String, method: String, body: Data?, query: [URLQueryItem] = []) async throws -> Data {
        let finalURL = try makeURL(path: path, query: query)
        var request = URLRequest(url: finalURL)
        request.httpMethod = method
        request.httpBody = body
        if body != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let token = try await accessTokenProvider()
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ChatAPIError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            let text = String(data: data, encoding: .utf8) ?? ""
            throw ChatAPIError.httpStatus(http.statusCode, text)
        }
        return data
    }
}

public enum ChatAPIError: Error, Equatable {
    case invalidResponse
    case httpStatus(Int, String)
}

private struct SpacesResponseDTO: Decodable {
    var spaces: [SpaceDTO]?
    var nextPageToken: String?
}

private struct SpaceDTO: Decodable {
    var name: String
    var displayName: String?
    var spaceType: String?
}

private struct MessagesResponseDTO: Decodable {
    var messages: [MessageDTO]?
    var nextPageToken: String?
}

private struct MessageDTO: Decodable {
    var name: String
    var text: String?
    var createTime: Date?
    var sender: SenderDTO?
    var attachment: [AttachmentDTO]?
}

private struct SenderDTO: Decodable {
    var name: String?
    var displayName: String?
}

private struct AttachmentDTO: Decodable {
    var name: String?
}

private extension JSONDecoder {
    static var chat: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
