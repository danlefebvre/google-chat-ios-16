import Foundation
import GoogleChatMultiCore

/// Talks to the notification relay for account register/teardown.
/// Authenticated with the user's Google refresh token — not the relay admin secret.
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

    func registerAccount(
        account: LinkedAccount,
        refreshToken: String
    ) async throws {
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
        let (_, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard (200..<300).contains(status) else {
            throw ChatAPIError.httpStatus(status)
        }
    }

    func removeAccount(_ accountId: AccountID, refreshToken: String) async throws {
        let encoded = accountId.rawValue.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)
            ?? accountId.rawValue
        var request = URLRequest(
            url: baseURL.appendingPathComponent("accounts/\(encoded)")
        )
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(refreshToken)", forHTTPHeaderField: "Authorization")
        let (_, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard status == 204 else {
            throw ChatAPIError.httpStatus(status)
        }
    }
}
