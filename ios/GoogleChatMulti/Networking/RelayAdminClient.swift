import Foundation
import GoogleChatMultiCore

enum RelayClientError: LocalizedError {
    case requestFailed(status: Int, body: String)

    var errorDescription: String? {
        switch self {
        case let .requestFailed(status, body):
            return "HTTP \(status): \(body)"
        }
    }
}

/// Talks to the notification relay for account register/teardown.
/// Registration sends the Google refresh token once; teardown uses the opaque
/// relay credential returned by register — never the shared admin secret.
actor RelayAdminClient {
    static var shared: RelayAdminClient?

    private let baseURL: URL
    private let session: URLSession

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    static func configure(baseURL: URL) {
        shared = RelayAdminClient(baseURL: baseURL)
        AppLog.relay.debug("RelayAdminClient.shared set")
    }

    /// Registers the account and returns the opaque relay credential to store locally.
    func registerAccount(
        account: LinkedAccount,
        refreshToken: String
    ) async throws -> String {
        let url = try endpoint("accounts")
        AppLog.relay.info(
            "POST \(url.absoluteString, privacy: .public) accountId=\(account.id.rawValue, privacy: .public) email=\(account.email, privacy: .public) label=\(account.label, privacy: .public)"
        )
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // refreshToken is sent to the relay but never logged.
        let body: [String: String] = [
            "accountId": account.id.rawValue,
            "email": account.email,
            "label": account.label,
            "refreshToken": refreshToken,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        let responseBody = String(data: data, encoding: .utf8) ?? ""
        guard (200..<300).contains(status) else {
            AppLog.relay.error(
                "register failed status=\(status) body=\(responseBody, privacy: .public)"
            )
            throw RelayClientError.requestFailed(status: status, body: responseBody)
        }
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let credential = json["relayCredential"] as? String,
            !credential.isEmpty
        else {
            AppLog.relay.error(
                "register missing relayCredential status=\(status) body=\(responseBody, privacy: .public)"
            )
            throw RelayClientError.requestFailed(
                status: status,
                body: "missing relayCredential: \(responseBody)"
            )
        }
        let subscription = json["subscriptionName"] as? String ?? "(none)"
        AppLog.relay.info(
            "register ok subscription=\(subscription, privacy: .public) credentialBytes=\(credential.count)"
        )
        return credential
    }

    /// Clears the relay's durable Bark badge counter so the next push starts at 1.
    func resetBadge(relayCredential: String) async throws {
        let url = try endpoint("badge/reset")
        AppLog.relay.info("POST \(url.absoluteString, privacy: .public)")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(relayCredential)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard (200..<300).contains(status) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            AppLog.relay.error("badge reset failed status=\(status) body=\(body, privacy: .public)")
            throw RelayClientError.requestFailed(status: status, body: body)
        }
        AppLog.relay.info("badge reset ok")
    }

    /// Updates the relay-side display label used in push notification titles.
    func updateAccountLabel(
        _ accountId: AccountID,
        label: String,
        relayCredential: String
    ) async throws {
        let url = try accountsURL(accountId: accountId, invalidURLBody: "invalid relay label URL")
        AppLog.relay.info(
            "PATCH \(url.absoluteString, privacy: .public) label=\(label)"
        )
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(relayCredential)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["label": label])
        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard (200..<300).contains(status) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            AppLog.relay.error("label update failed status=\(status) body=\(body, privacy: .public)")
            throw RelayClientError.requestFailed(status: status, body: body)
        }
        AppLog.relay.info("label update ok accountId=\(accountId.rawValue, privacy: .public)")
    }

    func removeAccount(_ accountId: AccountID, relayCredential: String) async throws {
        // Account ids contain `https://…|sub`. Putting that in the path breaks on `/`
        // (and some proxies reject `%2F`). Use a query param instead.
        let url = try accountsURL(accountId: accountId, invalidURLBody: "invalid relay teardown URL")
        AppLog.relay.info("DELETE \(url.absoluteString, privacy: .public)")
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(relayCredential)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard status == 204 else {
            let body = String(data: data, encoding: .utf8) ?? ""
            AppLog.relay.error("teardown failed status=\(status) body=\(body, privacy: .public)")
            throw RelayClientError.requestFailed(status: status, body: body)
        }
        AppLog.relay.info("teardown ok accountId=\(accountId.rawValue, privacy: .public)")
    }

    /// Builds `/accounts?accountId=` so issuer URLs with `/` never go in the path.
    private func accountsURL(accountId: AccountID, invalidURLBody: String) throws -> URL {
        guard var components = URLComponents(url: try endpoint("accounts"), resolvingAgainstBaseURL: false)
        else {
            throw RelayClientError.requestFailed(status: -1, body: "invalid relay accounts URL")
        }
        components.queryItems = [URLQueryItem(name: "accountId", value: accountId.rawValue)]
        guard let url = components.url else {
            throw RelayClientError.requestFailed(status: -1, body: invalidURLBody)
        }
        return url
    }

    private func endpoint(_ path: String) throws -> URL {
        let root = baseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let trimmedPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(root)/\(trimmedPath)") else {
            throw RelayClientError.requestFailed(status: -1, body: "invalid relay URL for path \(path)")
        }
        return url
    }
}
