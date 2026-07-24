import XCTest
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import GoogleChatCore

final class ChatClientTests: XCTestCase {
    func testListSpacesUsesBearerTokenAndParsesPage() async throws {
        let transport = MockHTTPTransport { request in
            XCTAssertEqual(request.url?.path, "/v1/spaces")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer tok-work")
            let body = """
            {"spaces":[{"name":"spaces/AAA","displayName":"#eng","spaceType":"SPACE"}],"nextPageToken":null}
            """.data(using: .utf8)!
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, body)
        }
        let client = ChatClient(baseURL: URL(string: "https://chat.googleapis.com")!, transport: transport)
        let page = try await client.listSpaces(accessToken: "tok-work")
        XCTAssertEqual(page.spaces.first?.name, "spaces/AAA")
    }

    func testSendMessagePostsText() async throws {
        let transport = MockHTTPTransport { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/v1/spaces/AAA/messages")
            let json = try JSONSerialization.jsonObject(with: request.httpBody ?? Data()) as? [String: Any]
            XCTAssertEqual(json?["text"] as? String, "hello")
            let body = """
            {"name":"spaces/AAA/messages/1","sender":{"name":"users/me","displayName":"Me"},"text":"hello","createTime":"2026-07-24T12:00:00Z"}
            """.data(using: .utf8)!
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, body)
        }
        let client = ChatClient(baseURL: URL(string: "https://chat.googleapis.com")!, transport: transport)
        let msg = try await client.sendMessage(spaceName: "spaces/AAA", text: "hello", accessToken: "tok")
        XCTAssertEqual(msg.text, "hello")
    }

    func testCreateReactionPostsEmoji() async throws {
        let transport = MockHTTPTransport { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertTrue(request.url!.path.contains("/reactions"))
            let body = """
            {"name":"spaces/AAA/messages/1/reactions/2","emoji":{"unicode":"👍"}}
            """.data(using: .utf8)!
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, body)
        }
        let client = ChatClient(baseURL: URL(string: "https://chat.googleapis.com")!, transport: transport)
        let reaction = try await client.createReaction(
            messageName: "spaces/AAA/messages/1",
            emoji: "👍",
            accessToken: "tok"
        )
        XCTAssertEqual(reaction.emoji.unicode, "👍")
    }
}

struct MockHTTPTransport: HTTPTransport, @unchecked Sendable {
    let handler: @Sendable (URLRequest) throws -> (HTTPURLResponse, Data)

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        let (response, data) = try handler(request)
        return (data, response)
    }
}
