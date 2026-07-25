import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Resolves Chat `users/{id}` resource names to display names via People API.
/// Chat user ids match People person ids (`users/123` ↔ `people/123`).
///
/// `people:batchGet` often returns empty `names` for Chat peers who are not in
/// the caller's contacts/directory. In that case we fall back to Other Contacts
/// (interaction-created), matching PROFILE source ids to Chat user ids.
public actor PeopleClient {
    private let session: URLSession
    private let tokens: any TokenProviding
    private let baseURL: URL
    /// accountId.rawValue → users/{id} → display name (from otherContacts).
    private var otherContactCache: [String: [String: String]] = [:]

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

        let stillMissing = unique.filter { result[$0] == nil }
        if !stillMissing.isEmpty {
            let fromOther = await otherContactNames(accountId: accountId)
            for key in stillMissing {
                if let label = fromOther[key], !label.isEmpty {
                    result[key] = label
                }
            }
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
        var items = [
            URLQueryItem(name: "personFields", value: "names,nicknames,emailAddresses"),
        ]
        for chatName in chatUserNames {
            guard let peopleName = Self.peopleResourceName(fromChatUser: chatName) else { continue }
            items.append(URLQueryItem(name: "resourceNames", value: peopleName))
        }
        components.queryItems = items
        guard let url = components.url else { throw ChatAPIError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let data = try await authorizedData(for: &request, accountId: accountId)
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

    private func otherContactNames(accountId: AccountID) async -> [String: String] {
        if let cached = otherContactCache[accountId.rawValue] { return cached }
        do {
            let map = try await fetchOtherContactIndex(accountId: accountId)
            otherContactCache[accountId.rawValue] = map
            return map
        } catch {
            otherContactCache[accountId.rawValue] = [:]
            return [:]
        }
    }

    private func fetchOtherContactIndex(accountId: AccountID) async throws -> [String: String] {
        var map: [String: String] = [:]
        var pageToken: String? = nil
        var pages = 0
        repeat {
            pages += 1
            if pages > 20 { break }
            var components = URLComponents(
                url: baseURL.appendingPathComponent("otherContacts"),
                resolvingAgainstBaseURL: false
            )!
            var items = [
                URLQueryItem(name: "pageSize", value: "1000"),
                URLQueryItem(name: "readMask", value: "names,nicknames,emailAddresses,metadata"),
                URLQueryItem(name: "sources", value: "READ_SOURCE_TYPE_CONTACT"),
                URLQueryItem(name: "sources", value: "READ_SOURCE_TYPE_PROFILE"),
            ]
            if let pageToken { items.append(URLQueryItem(name: "pageToken", value: pageToken)) }
            components.queryItems = items
            guard let url = components.url else { throw ChatAPIError.invalidURL }

            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            let data = try await authorizedData(for: &request, accountId: accountId)

            let decoded = try JSONDecoder().decode(OtherContactsListResponse.self, from: data)
            for person in decoded.otherContacts ?? [] {
                guard let label = person.resolvedDisplayName, !label.isEmpty else { continue }
                for chatName in person.linkedChatUserNames {
                    map[chatName] = label
                }
            }
            pageToken = decoded.nextPageToken
        } while pageToken != nil && !(pageToken?.isEmpty ?? true)
        return map
    }

    private func authorizedData(
        for request: inout URLRequest,
        accountId: AccountID,
        allowRetry: Bool = true
    ) async throws -> Data {
        let token = try await tokens.accessToken(for: accountId)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.dataCompat(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        if status == 401, allowRetry {
            await tokens.invalidateAccessToken(for: accountId)
            return try await authorizedData(for: &request, accountId: accountId, allowRetry: false)
        }
        guard (200..<300).contains(status) else { throw ChatAPIError.httpStatus(status) }
        guard !data.isEmpty else { throw ChatAPIError.emptyBody }
        return data
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

struct OtherContactsListResponse: Codable, Sendable {
    var otherContacts: [PeoplePerson]?
    var nextPageToken: String?
}

struct PeoplePerson: Codable, Sendable {
    var resourceName: String?
    var names: [PeopleName]?
    var nicknames: [PeopleNickname]?
    var emailAddresses: [PeopleEmail]?
    var metadata: PeopleMetadata?

    var resolvedDisplayName: String? {
        resolvedDisplayNameFromNames
            ?? resolvedDisplayNameFromNicknames
            ?? resolvedDisplayNameFromEmail
    }

    private var resolvedDisplayNameFromNames: String? {
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

    private var resolvedDisplayNameFromNicknames: String? {
        for nick in nicknames ?? [] {
            let value = nick.value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !value.isEmpty { return value }
        }
        return nil
    }

    private var resolvedDisplayNameFromEmail: String? {
        for email in emailAddresses ?? [] {
            let value = email.value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !value.isEmpty { return value }
        }
        return nil
    }

    /// Chat `users/{id}` keys linked via PROFILE source id or `people/{id}` resource.
    var linkedChatUserNames: [String] {
        var keys = Set<String>()
        if let resourceName, let chat = PeopleClient.chatUserName(fromPeople: resourceName) {
            keys.insert(chat)
        }
        for source in metadata?.sources ?? [] {
            let type = (source.type ?? "").uppercased()
            guard type.contains("PROFILE"),
                  let id = source.id?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !id.isEmpty, id != "me"
            else { continue }
            keys.insert("users/\(id)")
        }
        return Array(keys)
    }
}

struct PeopleName: Codable, Sendable {
    var displayName: String?
    var givenName: String?
    var familyName: String?
}

struct PeopleNickname: Codable, Sendable {
    var value: String?
}

struct PeopleEmail: Codable, Sendable {
    var value: String?
}

struct PeopleMetadata: Codable, Sendable {
    var sources: [PeopleSource]?
}

struct PeopleSource: Codable, Sendable {
    var type: String?
    var id: String?
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
