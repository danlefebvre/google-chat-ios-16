import XCTest
@testable import GoogleChatCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

final class MockTransport: HTTPTransport, @unchecked Sendable {
    private let lock = NSLock()
    private(set) var requests: [URLRequest] = []
    private let handler: (URLRequest) throws -> (Data, URLResponse)

    init(handler: @escaping (URLRequest) throws -> (Data, URLResponse)) {
        self.handler = handler
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        lock.lock()
        requests.append(request)
        lock.unlock()
        return try handler(request)
    }
}

final class ChatClientTests: XCTestCase {
    func testListSpacesSendsBearerToken() async throws {
        let json = """
        {"spaces":[{"name":"spaces/AAA","displayName":"Room","spaceType":"SPACE"}]}
        """.data(using: .utf8)!
        let transport = MockTransport { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (json, response)
        }
        let client = ChatClient(
            baseURL: URL(string: "https://chat.googleapis.com/v1/")!,
            transport: transport
        )
        let page = try await client.listSpaces(accessToken: "tok-123")
        XCTAssertEqual(page.spaces.first?.name, "spaces/AAA")
        XCTAssertEqual(transport.requests.first?.value(forHTTPHeaderField: "Authorization"), "Bearer tok-123")
    }

    func testSendMessagePostsJSON() async throws {
        let json = """
        {"name":"spaces/AAA/messages/1","text":"hello","createTime":"2026-07-24T12:00:00Z"}
        """.data(using: .utf8)!
        let transport = MockTransport { request in
            XCTAssertEqual(request.httpMethod, "POST")
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (json, response)
        }
        let client = ChatClient(
            baseURL: URL(string: "https://chat.googleapis.com/v1/")!,
            transport: transport
        )
        let msg = try await client.sendMessage(accessToken: "t", spaceName: "spaces/AAA", text: "hello")
        XCTAssertEqual(msg.text, "hello")
    }
}
