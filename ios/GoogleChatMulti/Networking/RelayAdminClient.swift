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
    }

    /// Registers the account and returns the opaque relay credential to store locally.
    func registerAccount(
        account: LinkedAccount,
        refreshToken: String
    ) async throws -> String {
        var request = URLRequest(url: baseURL.appendingPathComponent("accounts"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: String] = [
            "accountId": account.id.rawValue,
            "email": account.email,
            "label": account.label,
            "refreshToken": refreshToken,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard (200..<300).contains(status) else {
            if let body = String(data: data, encoding: .utf8), !body.isEmpty {
                throw RelayClientError.requestFailed(status: status, body: body)
            }
            throw ChatAPIError.httpStatus(status)
        }
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let credential = json["relayCredential"] as? String,
            !credential.isEmpty
        else {
            throw ChatAPIError.decodingFailed
        }
        return credential
    }

    func removeAccount(_ accountId: AccountID, relayCredential: String) async throws {
        let encoded = accountId.rawValue.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)
            ?? accountId.rawValue
        var request = URLRequest(
            url: baseURL.appendingPathComponent("accounts/\(encoded)")
        )
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(relayCredential)", forHTTPHeaderField: "Authorization")
        let (_, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard status == 204 else {
            throw ChatAPIError.httpStatus(status)
        }
    }
}
