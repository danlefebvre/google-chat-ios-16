import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Chat media download helpers.
public struct MediaClient: Sendable {
    public var session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func downloadAttachment(
        resourceName: String,
        accessToken: String
    ) async throws -> Data {
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

        let (data, response) = try await session.dataCompat(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard (200..<300).contains(status) else { throw ChatAPIError.httpStatus(status) }
        return data
    }
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
