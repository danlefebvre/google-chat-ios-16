import Foundation
import GoogleChatMultiCore

/// Talks to the notification relay for account register/teardown.
actor RelayAdminClient {
    static var shared: RelayAdminClient?

    private let baseURL: URL
    private let adminToken: String
    private let session: URLSession

    init(baseURL: URL, adminToken: String, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.adminToken = adminToken
        self.session = session
    }

    static func configure(baseURL: URL, adminToken: String) {
        shared = RelayAdminClient(baseURL: baseURL, adminToken: adminToken)
    }

    func registerAccount(
        account: LinkedAccount,
        refreshToken: String
    ) async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent("admin/accounts"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(adminToken)", forHTTPHeaderField: "Authorization")
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

    func removeAccount(_ accountId: AccountID) async {
        let encoded = accountId.rawValue.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)
            ?? accountId.rawValue
        var request = URLRequest(
            url: baseURL.appendingPathComponent("admin/accounts/\(encoded)")
        )
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(adminToken)", forHTTPHeaderField: "Authorization")
        _ = try? await session.data(for: request)
    }
}
