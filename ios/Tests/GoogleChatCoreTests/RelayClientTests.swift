import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import GoogleChatCore

final class RelayClientTests: XCTestCase {
    func testRegisterAccountPostsRefreshToken() async throws {
        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertTrue(request.url?.path.hasSuffix("/v1/accounts") == true)
            let body = try XCTUnwrap(request.httpBody ?? Data())
            let obj = try JSONSerialization.jsonObject(with: body) as! [String: Any]
            XCTAssertEqual(obj["id"] as? String, "iss|work")
            XCTAssertEqual(obj["refreshToken"] as? String, "rt")
            let data = #"{"id":"iss|work"}"#.data(using: .utf8)!
            return (HTTPURLResponse(url: request.url!, statusCode: 201, httpVersion: nil, headerFields: nil)!, data)
        }
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let client = RelayClient(baseURL: URL(string: "https://relay.example")!, session: URLSession(configuration: config))
        try await client.registerAccount(
            accountID: AccountID(issuer: "iss", subject: "work"),
            email: "w@ex.com",
            label: "Work",
            refreshToken: "rt"
        )
    }

    func testRemoveAccountCallsDelete() async throws {
        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.httpMethod, "DELETE")
            XCTAssertTrue(request.url?.path.contains("/v1/accounts/") == true)
            return (HTTPURLResponse(url: request.url!, statusCode: 204, httpVersion: nil, headerFields: nil)!, Data())
        }
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let client = RelayClient(baseURL: URL(string: "https://relay.example")!, session: URLSession(configuration: config))
        try await client.removeAccount(AccountID(issuer: "iss", subject: "work"))
    }
}
