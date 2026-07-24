import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct RelayClient: Sendable {
    public var baseURL: URL
    public var session: URLSession
    /// Shared secret for management routes (`RELAY_API_TOKEN`). Empty skips the Authorization header.
    public var apiToken: String

    public init(baseURL: URL, session: URLSession = .shared, apiToken: String = "") {
        self.baseURL = baseURL
        self.session = session
        self.apiToken = apiToken
    }

    public func registerAccount(
        accountID: AccountID,
        email: String,
        label: String,
        refreshToken: String
    ) async throws {
        let url = baseURL.appendingPathComponent("v1/accounts")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applyAuth(&request)
        let body: [String: Any] = [
            "id": accountID.rawValue,
            "email": email,
            "label": label,
            "refreshToken": refreshToken,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw RelayClientError.unexpectedStatus
        }
    }

    public func removeAccount(_ accountID: AccountID) async throws {
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "/")
        let encoded = accountID.rawValue.addingPercentEncoding(withAllowedCharacters: allowed) ?? accountID.rawValue
        let url = baseURL.appendingPathComponent("v1/accounts/\(encoded)")
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        applyAuth(&request)
        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw RelayClientError.unexpectedStatus
        }
    }

    public func setMuted(accountID: AccountID, spaceName: String?, muted: Bool) async throws {
        let url = baseURL.appendingPathComponent("v1/mutes")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applyAuth(&request)
        var body: [String: Any] = [
            "accountId": accountID.rawValue,
            "muted": muted,
            "scope": spaceName == nil ? "account" : "space",
        ]
        if let spaceName {
            body["spaceName"] = spaceName
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw RelayClientError.unexpectedStatus
        }
    }

    private func applyAuth(_ request: inout URLRequest) {
        guard !apiToken.isEmpty else { return }
        request.setValue("Bearer \(apiToken)", forHTTPHeaderField: "Authorization")
    }
}

public enum RelayClientError: Error {
    case unexpectedStatus
}
