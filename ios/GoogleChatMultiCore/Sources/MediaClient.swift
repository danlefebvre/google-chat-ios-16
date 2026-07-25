import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Chat media download helpers with iPhone 8 memory limits (from PR #8).
public struct MediaClient: Sendable {
    public var session: URLSession
    public var maxBytes: Int

    public init(session: URLSession = .shared, maxBytes: Int = 1_500_000) {
        self.session = session
        self.maxBytes = maxBytes
    }

    public func downloadAttachment(
        resourceName: String,
        accessToken: String,
        maxBytes: Int? = nil
    ) async throws -> Data {
        let limit = maxBytes ?? self.maxBytes
        // resourceName may contain slashes (e.g. spaces/.../files/...); keep them as path segments.
        let trimmed = resourceName.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard
            let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
            var components = URLComponents(string: "https://chat.googleapis.com/v1/media/\(encoded)")
        else {
            throw ChatAPIError.invalidURL
        }
        components.queryItems = [URLQueryItem(name: "alt", value: "media")]
        guard let url = components.url else { throw ChatAPIError.invalidURL }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        return try await downloadCapped(request: request, limit: limit)
    }

    /// Streams the response and aborts once `limit` is exceeded so oversized bodies are not fully buffered.
    private func downloadCapped(request: URLRequest, limit: Int) async throws -> Data {
        #if canImport(FoundationNetworking)
        // Linux/FoundationNetworking: fall back to full-buffer download with Content-Length check.
        let (data, response) = try await session.dataCompat(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard (200..<300).contains(status) else { throw ChatAPIError.httpStatus(status) }
        if let http = response as? HTTPURLResponse, http.expectedContentLength > limit {
            throw MediaClientError.tooLarge(Int(http.expectedContentLength), limit)
        }
        if data.count > limit { throw MediaClientError.tooLarge(data.count, limit) }
        return data
        #else
        let (bytes, response) = try await session.bytes(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ChatAPIError.httpStatus((response as? HTTPURLResponse)?.statusCode ?? -1)
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
        #endif
    }
}

public enum MediaClientError: Error, Equatable, Sendable {
    case tooLarge(Int, Int)
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
