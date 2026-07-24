import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Chat media download/upload helpers with iPhone 8 memory limits.
public struct MediaClient: Sendable {
    public var baseURL: URL
    public var session: URLSession
    public var accessTokenProvider: @Sendable () async throws -> String
    public var policy: AttachmentMemoryPolicy

    public init(
        baseURL: URL = URL(string: "https://chat.googleapis.com")!,
        session: URLSession = .shared,
        accessTokenProvider: @escaping @Sendable () async throws -> String,
        policy: AttachmentMemoryPolicy = .iPhone8
    ) {
        self.baseURL = baseURL
        self.session = session
        self.accessTokenProvider = accessTokenProvider
        self.policy = policy
    }

    public func downloadAttachment(resourceName: String, maxBytes: Int? = nil) async throws -> Data {
        let limit = maxBytes ?? policy.maxDecodedThumbnailBytes
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw ChatAPIError.invalidResponse
        }
        components.path = "/v1/media/" + resourceName.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        components.queryItems = [URLQueryItem(name: "alt", value: "media")]
        guard let url = components.url else { throw ChatAPIError.invalidResponse }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(try await accessTokenProvider())", forHTTPHeaderField: "Authorization")
        return try await downloadCapped(request: request, limit: limit)
    }

    /// Streams the response and aborts once `limit` is exceeded so oversized bodies are not fully buffered.
    private func downloadCapped(request: URLRequest, limit: Int) async throws -> Data {
        let (bytes, response) = try await session.bytes(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ChatAPIError.invalidResponse
        }
        if http.expectedContentLength > 0, http.expectedContentLength > limit {
            throw MediaClientError.tooLarge(Int(http.expectedContentLength), limit)
        }

        var data = Data()
        data.reserveCapacity(min(limit, 64 * 1024))
        for try await byte in bytes {
            data.append(byte)
            if data.count > limit {
                throw MediaClientError.tooLarge(data.count, limit)
            }
        }
        return data
    }
}

public enum MediaClientError: Error, Equatable {
    case tooLarge(Int, Int)
}
