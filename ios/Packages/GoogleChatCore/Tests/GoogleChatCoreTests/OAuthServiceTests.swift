import XCTest
@testable import GoogleChatCore

final class OAuthServiceTests: XCTestCase {
    func testParsesStoredAccountFromTokenResponse() throws {
        let header = Data("{}".utf8).base64EncodedString()
        let payloadJSON = """
        {"iss":"https://accounts.google.com","sub":"123","email":"alice@example.com"}
        """
        let payload = Data(payloadJSON.utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        let idToken = "\(header).\(payload).signature"

        let token = OAuthTokenResponse(
            accessToken: "access",
            refreshToken: "refresh",
            expiresIn: 3600,
            idToken: idToken
        )

        let account = try OAuthService.storedAccount(
            from: token,
            label: "Work",
            color: .work,
            now: Date(timeIntervalSince1970: 0)
        )

        XCTAssertEqual(account.label, "Work")
        XCTAssertEqual(account.accountId.subject, "123")
        XCTAssertEqual(account.accessToken, "access")
        XCTAssertEqual(account.expiresAt, Date(timeIntervalSince1970: 3600))
    }
}
