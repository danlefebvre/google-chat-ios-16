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

    func testListMessagesKeepsSlashInSpaceResourcePath() async throws {
        let account = AccountID(issuer: "https://accounts.google.com", subject: "work")
        URLProtocolStub.handler = { request in
            let path = request.url?.path ?? ""
            XCTAssertTrue(path.contains("/spaces/AAA/messages"), "got \(path)")
            XCTAssertFalse(path.contains("spaces%2F"), "got \(path)")
            let json = #"{"messages":[]}"#.data(using: .utf8)!
            return (
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                json
            )
        }

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [URLProtocolStub.self]
        let client = ChatAPIClient(
            tokens: StubTokens(["\(account.rawValue)": "tok"]),
            session: URLSession(configuration: config)
        )
        _ = try await client.listMessages(accountId: account, spaceName: "spaces/AAA", pageSize: 1)
    }

    func testListMessagesIncludesPageTokenQueryItem() async throws {
        let account = AccountID(issuer: "https://accounts.google.com", subject: "work")
        URLProtocolStub.handler = { request in
            let items = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
            XCTAssertEqual(items.first(where: { $0.name == "pageToken" })?.value, "page-2")
            XCTAssertEqual(items.first(where: { $0.name == "pageSize" })?.value, "40")
            XCTAssertEqual(items.first(where: { $0.name == "orderBy" })?.value, "createTime desc")
            let json = #"{"messages":[],"nextPageToken":"page-3"}"#.data(using: .utf8)!
            return (
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                json
            )
        }

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [URLProtocolStub.self]
        let client = ChatAPIClient(
            tokens: StubTokens(["\(account.rawValue)": "tok"]),
            session: URLSession(configuration: config)
        )
        let response = try await client.listMessages(
            accountId: account,
            spaceName: "spaces/AAA",
            pageSize: 40,
            pageToken: "page-2"
        )
        XCTAssertEqual(response.nextPageToken, "page-3")
    }

    func testListSpacesRetriesOnceAfter401WithRefreshedToken() async throws {
        let account = AccountID(issuer: "https://accounts.google.com", subject: "work")
        let tokens = StubTokens(
            ["\(account.rawValue)": "expired-tok"],
            refreshMap: ["\(account.rawValue)": "fresh-tok"]
        )
        var seenAuth: [String] = []

        URLProtocolStub.handler = { request in
            let auth = request.value(forHTTPHeaderField: "Authorization") ?? ""
            seenAuth.append(auth)
            if auth.contains("expired-tok") {
                return (
                    HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!,
                    Data()
                )
            }
            let json = ##"{"spaces":[{"name":"spaces/AAA","displayName":"eng","spaceType":"SPACE"}]}"##
                .data(using: .utf8)!
            return (
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                json
            )
        }

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [URLProtocolStub.self]
        let client = ChatAPIClient(
            tokens: tokens,
            session: URLSession(configuration: config)
        )

        let result = try await client.listSpaces(accountId: account)
        XCTAssertEqual(result.spaces.first?.name, "spaces/AAA")
        XCTAssertEqual(tokens.invalidateCount, 1)
        XCTAssertEqual(seenAuth, ["Bearer expired-tok", "Bearer fresh-tok"])
    }
}

private final class StubTokens: TokenProviding, @unchecked Sendable {
    private var map: [String: String]
    private var refreshMap: [String: String]
    private(set) var invalidateCount = 0
    private(set) var accessCalls = 0

    init(_ map: [String: String], refreshMap: [String: String] = [:]) {
        self.map = map
        self.refreshMap = refreshMap
    }

    func accessToken(for accountId: AccountID) async throws -> String {
        accessCalls += 1
        if let token = map[accountId.rawValue], !token.isEmpty {
            return token
        }
        if let refreshed = refreshMap[accountId.rawValue], !refreshed.isEmpty {
            map[accountId.rawValue] = refreshed
            return refreshed
        }
        throw ChatAPIError.httpStatus(401)
    }

    func invalidateAccessToken(for accountId: AccountID) async {
        invalidateCount += 1
        map[accountId.rawValue] = ""
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
