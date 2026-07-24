import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import GoogleChatMultiCore

final class InboxSyncTests: XCTestCase {
    func testRefreshAccountsFollowsSpaceListPagination() async throws {
        let account = LinkedAccount(
            id: AccountID(issuer: "https://accounts.google.com", subject: "work"),
            email: "you@work.com",
            label: "Work",
            colorHex: "#C45C26"
        )

        var calls = 0
        URLProtocolStub.handler = { request in
            calls += 1
            let url = request.url!.absoluteString
            if url.contains("/spaces") {
                let pageToken = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?
                    .queryItems?.first(where: { $0.name == "pageToken" })?.value
                let json: Data
                if pageToken == nil {
                    json = """
                    {"spaces":[{"name":"spaces/A","displayName":"One","spaceType":"SPACE"}],"nextPageToken":"p2"}
                    """.data(using: .utf8)!
                } else {
                    json = """
                    {"spaces":[{"name":"spaces/B","displayName":"Two","spaceType":"SPACE"}]}
                    """.data(using: .utf8)!
                }
                return (
                    HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    json
                )
            }
            // listMessages — empty is fine
            let json = #"{"messages":[]}"#.data(using: .utf8)!
            return (
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                json
            )
        }

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [URLProtocolStub.self]
        let client = ChatAPIClient(
            tokens: StubTokens(["\(account.id.rawValue)": "tok"]),
            session: URLSession(configuration: config)
        )
        let cache = InMemoryConversationCache()
        let sync = InboxSyncService(api: client, cache: cache)

        let rows = try await sync.refreshAccounts([account])
        XCTAssertEqual(Set(rows.map(\.spaceName)), Set(["spaces/A", "spaces/B"]))
        XCTAssertGreaterThanOrEqual(calls, 2)
    }

    func testReplaceConversationsDropsStaleRows() async throws {
        let cache = InMemoryConversationCache()
        let account = AccountID(issuer: "https://accounts.google.com", subject: "work")
        try await cache.replaceConversations([
            ConversationSummary(
                accountId: account,
                accountLabel: "Work",
                accountColorHex: "#C45C26",
                spaceName: "spaces/OLD",
                title: "Old",
                lastMessagePreview: "",
                lastActivityAt: Date(timeIntervalSince1970: 1),
                unreadCount: 0,
                isDirectMessage: false
            ),
        ])
        try await cache.replaceConversations([
            ConversationSummary(
                accountId: account,
                accountLabel: "Work",
                accountColorHex: "#C45C26",
                spaceName: "spaces/NEW",
                title: "New",
                lastMessagePreview: "",
                lastActivityAt: Date(timeIntervalSince1970: 2),
                unreadCount: 0,
                isDirectMessage: false
            ),
        ])
        let loaded = try await cache.loadConversations()
        XCTAssertEqual(loaded.map(\.spaceName), ["spaces/NEW"])
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
