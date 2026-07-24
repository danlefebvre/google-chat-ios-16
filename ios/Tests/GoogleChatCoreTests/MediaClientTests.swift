import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import GoogleChatCore

final class MediaClientTests: XCTestCase {
    func testDownloadRejectsOversizedPayload() async {
        let huge = Data(repeating: 1, count: 600_000)
        MockURLProtocol.requestHandler = { request in
            (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, huge)
        }
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let client = MediaClient(
            session: URLSession(configuration: config),
            accessTokenProvider: { "tok" },
            policy: .iPhone8
        )
        do {
            _ = try await client.downloadAttachment(resourceName: "attachments/1")
            XCTFail("expected tooLarge")
        } catch let error as MediaClientError {
            guard case .tooLarge = error else {
                return XCTFail("wrong error \(error)")
            }
        } catch {
            XCTFail("unexpected \(error)")
        }
    }

    func testDownloadAcceptsSmallPayload() async throws {
        let payload = Data("tiny".utf8)
        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer tok")
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, payload)
        }
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let client = MediaClient(
            session: URLSession(configuration: config),
            accessTokenProvider: { "tok" }
        )
        let data = try await client.downloadAttachment(resourceName: "attachments/1")
        XCTAssertEqual(data, payload)
    }
}
