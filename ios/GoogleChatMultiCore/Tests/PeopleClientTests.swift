import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import GoogleChatMultiCore

final class PeopleClientTests: XCTestCase {
    func testMapsChatUserToPeopleResource() {
        XCTAssertEqual(
            PeopleClient.peopleResourceName(fromChatUser: "users/123456789"),
            "people/123456789"
        )
        XCTAssertNil(PeopleClient.peopleResourceName(fromChatUser: "users/me"))
        XCTAssertNil(PeopleClient.peopleResourceName(fromChatUser: "spaces/AAA"))
    }

    func testMapsPeopleResourceToChatUser() {
        XCTAssertEqual(
            PeopleClient.chatUserName(fromPeople: "people/123456789"),
            "users/123456789"
        )
        XCTAssertNil(PeopleClient.chatUserName(fromPeople: "people/me"))
    }

    func testAccountIDChatUserName() {
        let id = AccountID(issuer: "https://accounts.google.com", subject: "99")
        XCTAssertEqual(id.chatUserName, "users/99")
    }

    func testHasHumanReadableNameRejectsNumericIds() {
        XCTAssertTrue(ChatSender(name: "users/1", displayName: "Alice").hasHumanReadableName)
        XCTAssertFalse(ChatSender(name: "users/1", displayName: "123456789").hasHumanReadableName)
        XCTAssertFalse(ChatSender(name: "users/1", displayName: nil).hasHumanReadableName)
        XCTAssertFalse(ChatSender(name: "users/1", displayName: "users/1").hasHumanReadableName)
        XCTAssertEqual(ChatSender(name: "users/1", displayName: nil).resolvedDisplayName, "Someone")
    }

    func testBatchGetParsesDisplayNames() async throws {
        let account = AccountID(issuer: "https://accounts.google.com", subject: "me")
        URLProtocolStub.handler = { request in
            let url = request.url!.absoluteString
            XCTAssertTrue(url.contains("people:batchGet"))
            let json = """
            {
              "responses": [
                {
                  "requestedResourceName": "people/111",
                  "person": {
                    "resourceName": "people/111",
                    "names": [{ "displayName": "Alice Example" }]
                  }
                },
                {
                  "requestedResourceName": "people/222",
                  "person": {
                    "resourceName": "people/222",
                    "names": [{ "givenName": "Bob", "familyName": "Builder" }]
                  }
                }
              ]
            }
            """.data(using: .utf8)!
            return (
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                json
            )
        }

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [URLProtocolStub.self]
        let client = PeopleClient(
            tokens: StubTokens(["\(account.rawValue)": "tok"]),
            session: URLSession(configuration: config)
        )

        let names = try await client.displayNames(
            accountId: account,
            chatUserNames: ["users/111", "users/222"]
        )
        XCTAssertEqual(names["users/111"], "Alice Example")
        XCTAssertEqual(names["users/222"], "Bob Builder")
    }

    func testOtherContactsFallbackFillsEmptyBatchGetNames() async throws {
        let account = AccountID(issuer: "https://accounts.google.com", subject: "me")
        URLProtocolStub.handler = { request in
            let url = request.url!.absoluteString
            if url.contains("people:batchGet") {
                let json = """
                {
                  "responses": [
                    {
                      "requestedResourceName": "people/999",
                      "person": { "resourceName": "people/999" }
                    }
                  ]
                }
                """.data(using: .utf8)!
                return (
                    HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    json
                )
            }
            if url.contains("otherContacts") {
                let json = """
                {
                  "otherContacts": [
                    {
                      "resourceName": "otherContacts/c1",
                      "names": [{ "displayName": "Casey Chat" }],
                      "metadata": {
                        "sources": [
                          { "type": "PROFILE", "id": "999" },
                          { "type": "OTHER_CONTACT", "id": "c1" }
                        ]
                      }
                    }
                  ]
                }
                """.data(using: .utf8)!
                return (
                    HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    json
                )
            }
            throw URLError(.badURL)
        }

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [URLProtocolStub.self]
        let client = PeopleClient(
            tokens: StubTokens(["\(account.rawValue)": "tok"]),
            session: URLSession(configuration: config)
        )

        let names = try await client.displayNames(
            accountId: account,
            chatUserNames: ["users/999"]
        )
        XCTAssertEqual(names["users/999"], "Casey Chat")
    }

    func testBatchGetFallsBackToEmailWhenNamesMissing() async throws {
        let account = AccountID(issuer: "https://accounts.google.com", subject: "me")
        URLProtocolStub.handler = { request in
            let json = """
            {
              "responses": [
                {
                  "requestedResourceName": "people/555",
                  "person": {
                    "resourceName": "people/555",
                    "emailAddresses": [{ "value": "pat@example.com" }]
                  }
                }
              ]
            }
            """.data(using: .utf8)!
            return (
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                json
            )
        }

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [URLProtocolStub.self]
        let client = PeopleClient(
            tokens: StubTokens(["\(account.rawValue)": "tok"]),
            session: URLSession(configuration: config)
        )

        let names = try await client.displayNames(
            accountId: account,
            chatUserNames: ["users/555"]
        )
        XCTAssertEqual(names["users/555"], "pat@example.com")
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
