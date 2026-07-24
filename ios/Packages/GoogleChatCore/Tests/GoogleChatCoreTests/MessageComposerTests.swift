import XCTest
@testable import GoogleChatCore

final class MessageComposerTests: XCTestCase {
    func testBuildsCreateMessageRequestBody() throws {
        let body = try MessageComposer.createTextMessageBody(text: "hello team")
        let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]
        XCTAssertEqual(json?["text"] as? String, "hello team")
    }

    func testRejectsEmptyMessage() {
        XCTAssertThrowsError(try MessageComposer.createTextMessageBody(text: "   "))
    }
}
