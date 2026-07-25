import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Resolves Chat `users/{id}` resource names to display names via People API.
/// Chat user ids match People person ids (`users/123` ↔ `people/123`).
public actor PeopleClient {
    private let session: URLSession
    private let tokens: any TokenProviding
    private let baseURL: URL

    public init(
        tokens: any TokenProviding,
        session: URLSession = .shared,
        baseURL: URL = URL(string: "https://people.googleapis.com/v1")!
    ) {
        self.tokens = tokens
        self.session = session
        self.baseURL = baseURL
    }

    /// Returns a map of Chat user resource names (`users/…`) → display names.
    public func displayNames(
        accountId: AccountID,
        chatUserNames: [String]
    ) async throws -> [String: String] {
        let unique = Array(Set(chatUserNames.filter { !$0.isEmpty }))
        guard !unique.isEmpty else { return [:] }

        var result: [String: String] = [:]
        // People API batchGet allows up to 200 resource names per call.
        let chunkSize = 200
        var index = 0
        while index < unique.count {
            let end = min(index + chunkSize, unique.count)
            let chunk = Array(unique[index..<end])
            let partial = try await batchGetNames(accountId: accountId, chatUserNames: chunk)
            for (key, value) in partial { result[key] = value }
            index = end
        }
        return result
    }

    private func batchGetNames(
        accountId: AccountID,
        chatUserNames: [String]
    ) async throws -> [String: String] {
        var components = URLComponents(
            url: baseURL.appendingPathComponent("people:batchGet"),
            resolvingAgainstBaseURL: false
        )!
        var items = [URLQueryItem(name: "personFields", value: "names")]
        for chatName in chatUserNames {
            guard let peopleName = Self.peopleResourceName(fromChatUser: chatName) else { continue }
            items.append(URLQueryItem(name: "resourceNames", value: peopleName))
        }
        components.queryItems = items
        guard let url = components.url else { throw ChatAPIError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let token = try await tokens.accessToken(for: accountId)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.dataCompat(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard (200..<300).contains(status) else { throw ChatAPIError.httpStatus(status) }
        guard !data.isEmpty else { throw ChatAPIError.emptyBody }

        let decoded = try JSONDecoder().decode(PeopleBatchGetResponse.self, from: data)
        var map: [String: String] = [:]
        for entry in decoded.responses ?? [] {
            let peopleName = entry.person?.resourceName ?? entry.requestedResourceName
            guard let peopleName,
                  let chatName = Self.chatUserName(fromPeople: peopleName),
                  let label = entry.person?.resolvedDisplayName
            else { continue }
            map[chatName] = label
        }
        return map
    }

    public static func peopleResourceName(fromChatUser chatUserName: String) -> String? {
        guard chatUserName.hasPrefix("users/") else { return nil }
        let id = String(chatUserName.dropFirst("users/".count))
        guard !id.isEmpty, id != "me", id != "app" else { return nil }
        return "people/\(id)"
    }

    public static func chatUserName(fromPeople peopleName: String) -> String? {
        guard peopleName.hasPrefix("people/") else { return nil }
        let id = String(peopleName.dropFirst("people/".count))
        guard !id.isEmpty, id != "me" else { return nil }
        return "users/\(id)"
    }
}

struct PeopleBatchGetResponse: Codable, Sendable {
    var responses: [PeopleGetResponse]?
}

struct PeopleGetResponse: Codable, Sendable {
    var requestedResourceName: String?
    var person: PeoplePerson?
}

struct PeoplePerson: Codable, Sendable {
    var resourceName: String?
    var names: [PeopleName]?

    var resolvedDisplayName: String? {
        guard let names, !names.isEmpty else { return nil }
        for name in names {
            let display = name.displayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !display.isEmpty { return display }
            let given = name.givenName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let family = name.familyName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let joined = [given, family].filter { !$0.isEmpty }.joined(separator: " ")
            if !joined.isEmpty { return joined }
        }
        return nil
    }
}

struct PeopleName: Codable, Sendable {
    var displayName: String?
    var givenName: String?
    var familyName: String?
}

private extension URLSession {
    func dataCompat(for request: URLRequest) async throws -> (Data, URLResponse) {
        #if canImport(FoundationNetworking)
        try await withCheckedThrowingContinuation { continuation in
            let task = dataTask(with: request) { data, response, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: (data ?? Data(), response ?? URLResponse()))
                }
            }
            task.resume()
        }
        #else
        try await data(for: request)
        #endif
    }
}
