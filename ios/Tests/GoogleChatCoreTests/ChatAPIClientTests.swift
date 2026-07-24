import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import GoogleChatCore

final class ChatAPIClientTests: XCTestCase {
    func testListSpacesDecodes() async throws {
        let json = """
        {
          "spaces": [
            {"name":"spaces/AAA","displayName":"#eng-standup","spaceType":"SPACE"},
            {"name":"spaces/BBB","displayName":"","spaceType":"DIRECT_MESSAGE"}
          ],
          "nextPageToken": "page2"
        }
        """.data(using: .utf8)!

        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer tok")
            XCTAssertTrue(request.url?.path.contains("/v1/spaces") == true)
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, json)
        }

        let client = ChatAPIClient(
            session: makeMockSession(),
            accessTokenProvider: { "tok" }
        )
        let page = try await client.listSpaces(pageToken: nil, pageSize: 50)
        XCTAssertEqual(page.spaces.count, 2)
        XCTAssertEqual(page.spaces[0].name, "spaces/AAA")
        XCTAssertEqual(page.spaces[0].displayName, "#eng-standup")
        XCTAssertTrue(page.spaces[1].isDirectMessage)
        XCTAssertEqual(page.nextPageToken, "page2")
    }

    func testListMessagesDecodesSenderAndText() async throws {
        let json = """
        {
          "messages": [
            {
              "name":"spaces/AAA/messages/m1",
              "sender":{"name":"users/1","displayName":"Alice"},
              "text":"deploy looks good",
              "createTime":"2026-07-24T12:00:00Z",
              "attachment":[]
            }
          ]
        }
        """.data(using: .utf8)!

        MockURLProtocol.requestHandler = { request in
            XCTAssertTrue(request.url?.absoluteString.contains("spaces/AAA/messages") == true)
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, json)
        }

        let client = ChatAPIClient(session: makeMockSession(), accessTokenProvider: { "tok" })
        let page = try await client.listMessages(spaceName: "spaces/AAA", pageToken: nil, pageSize: 30)
        XCTAssertEqual(page.messages.count, 1)
        XCTAssertEqual(page.messages[0].text, "deploy looks good")
        XCTAssertEqual(page.messages[0].senderDisplayName, "Alice")
    }

    func testSendMessagePostsText() async throws {
        let json = """
        {"name":"spaces/AAA/messages/m2","text":"hello","createTime":"2026-07-24T12:01:00Z","sender":{"displayName":"You"}}
        """.data(using: .utf8)!

        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            let body = try XCTUnwrap(request.httpBody ?? request.bodyStreamData())
            let obj = try JSONSerialization.jsonObject(with: body) as! [String: Any]
            XCTAssertEqual(obj["text"] as? String, "hello")
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, json)
        }

        let client = ChatAPIClient(session: makeMockSession(), accessTokenProvider: { "tok" })
        let msg = try await client.sendMessage(spaceName: "spaces/AAA", text: "hello")
        XCTAssertEqual(msg.text, "hello")
    }

    func testCreateReaction() async throws {
        let json = #"{"name":"spaces/AAA/messages/m1/reactions/r1"}"#.data(using: .utf8)!
        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertTrue(request.url?.path.contains("/reactions") == true)
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, json)
        }
        let client = ChatAPIClient(session: makeMockSession(), accessTokenProvider: { "tok" })
        let name = try await client.createReaction(messageName: "spaces/AAA/messages/m1", emoji: "👍")
        XCTAssertTrue(name.contains("reactions"))
    }

    private func makeMockSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }
}

final class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
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

private extension URLRequest {
    func bodyStreamData() -> Data? {
        guard let stream = httpBodyStream else { return httpBody }
        stream.open()
        defer { stream.close() }
        var data = Data()
        let bufferSize = 1024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }
        while stream.hasBytesAvailable {
            let read = stream.read(buffer, maxLength: bufferSize)
            if read > 0 {
                data.append(buffer, count: read)
            } else {
                break
            }
        }
        return data
    }
}
