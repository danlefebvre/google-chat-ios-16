import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum RelayClientError: Error, Equatable {
    case invalidURL
    case httpStatus(Int)
}

/// Thin client for the notification relay (account teardown, etc.).
public struct RelayClient: Sendable {
    private let baseURL: URL
    private let transport: any HTTPTransport

    public init(baseURL: URL, transport: any HTTPTransport = URLSessionTransport()) {
        self.baseURL = baseURL
        self.transport = transport
    }

    /// DELETE /v1/accounts/{accountID} — must succeed before wiping local account state.
    public func teardownAccount(accountID: AccountID) async throws {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw RelayClientError.invalidURL
        }
        let encoded = accountID.key.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? accountID.key
        let basePath = components.path.hasSuffix("/") ? String(components.path.dropLast()) : components.path
        components.path = (basePath.isEmpty ? "" : basePath) + "/v1/accounts/" + encoded
        guard let url = components.url else { throw RelayClientError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        let (_, response) = try await transport.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw RelayClientError.httpStatus(-1)
        }
        guard (200..<300).contains(http.statusCode) else {
            throw RelayClientError.httpStatus(http.statusCode)
        }
    }
}
