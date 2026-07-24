import XCTest
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import GoogleChatCore

final class MediaClientTests: XCTestCase {
    func testUploadAttachmentPostsMultipart() async throws {
        let transport = MockHTTPTransport { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertTrue(request.url!.absoluteString.contains("uploadType=multipart"))
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer tok")
            let body = """
            {"attachmentDataRef":{"resourceName":"spaces/AAA/attachments/xyz","attachmentUploadToken":"tok-upload"}}
            """.data(using: .utf8)!
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, body)
        }
        let client = ChatClient(baseURL: URL(string: "https://chat.googleapis.com")!, transport: transport)
        let uploaded = try await client.uploadAttachment(
            spaceName: "spaces/AAA",
            fileName: "shot.png",
            contentType: "image/png",
            data: Data(repeating: 1, count: 16),
            accessToken: "tok"
        )
        XCTAssertEqual(uploaded.attachmentDataRef.resourceName, "spaces/AAA/attachments/xyz")
        XCTAssertEqual(uploaded.attachmentDataRef.attachmentUploadToken, "tok-upload")
    }

    func testDownloadAttachmentReturnsBytes() async throws {
        let payload = Data("png-bytes".utf8)
        let transport = MockHTTPTransport { request in
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertTrue(request.url!.path.contains("attachments/1"))
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, payload)
        }
        let client = ChatClient(baseURL: URL(string: "https://chat.googleapis.com")!, transport: transport)
        let data = try await client.downloadAttachment(
            attachmentName: "spaces/AAA/messages/1/attachments/1",
            accessToken: "tok"
        )
        XCTAssertEqual(data, payload)
    }
}
