import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct RelayClient: Sendable {
    public var baseURL: URL
    public var session: URLSession

    public init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
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
}

public enum RelayClientError: Error {
    case unexpectedStatus
}
