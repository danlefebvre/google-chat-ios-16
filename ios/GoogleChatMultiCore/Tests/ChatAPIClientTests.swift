import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import GoogleChatMultiCore

final class ChatAPIClientTests: XCTestCase {
    func testListSpacesSendsBearerTokenAndDecodes() async throws {
        let account = AccountID(issuer: "https://accounts.google.com", subject: "work")
        let json = """
        {"spaces":[{"name":"spaces/AAA","displayName":"#eng","spaceType":"SPACE"}]}
        """.data(using: .utf8)!

        URLProtocolStub.handler = { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer tok-work")
            XCTAssertTrue(request.url?.absoluteString.contains("/spaces") == true)
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, json)
        }

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [URLProtocolStub.self]
        let session = URLSession(configuration: config)
        let client = ChatAPIClient(
            tokens: StubTokens(["\(account.rawValue)": "tok-work"]),
            session: session
        )

        let result = try await client.listSpaces(accountId: account)
        XCTAssertEqual(result.spaces.first?.name, "spaces/AAA")
    }

    func testSendMessagePostsJSONBody() async throws {
        let account = AccountID(issuer: "https://accounts.google.com", subject: "work")
        let json = """
        {"name":"spaces/AAA/messages/1","text":"hello","sender":{"displayName":"You"}}
        """.data(using: .utf8)!

        URLProtocolStub.handler = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            if let body = request.httpBody,
               let obj = try? JSONSerialization.jsonObject(with: body) as? [String: Any] {
                XCTAssertEqual(obj["text"] as? String, "hello")
            } else {
                XCTFail("missing body")
            }
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, json)
        }

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [URLProtocolStub.self]
        let client = ChatAPIClient(
            tokens: StubTokens(["\(account.rawValue)": "tok"]),
            session: URLSession(configuration: config)
        )

        let message = try await client.sendMessage(
            accountId: account,
            spaceName: "spaces/AAA",
            text: "hello"
        )
        XCTAssertEqual(message.text, "hello")
    }
}

private struct StubTokens: TokenProviding {
    let map: [String: String]
    init(_ map: [String: String]) { self.map = map }
    func accessToken(for accountId: AccountID) async throws -> String {
        map[accountId.rawValue]!
    }
}

private final class URLProtocolStub: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = URLProtocolStub.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
