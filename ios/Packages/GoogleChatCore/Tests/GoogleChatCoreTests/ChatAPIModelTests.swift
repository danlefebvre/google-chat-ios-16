import XCTest
@testable import GoogleChatCore

final class ChatAPIModelTests: XCTestCase {
    func testDecodesSpaceListResponse() throws {
        let json = """
        {
          "spaces": [
            {
              "name": "spaces/abc",
              "displayName": "Engineering",
              "spaceType": "SPACE",
              "spaceHistoryState": "HISTORY_ON"
            }
          ],
          "nextPageToken": "token-1"
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder.api.decode(ListSpacesResponse.self, from: json)
        XCTAssertEqual(response.spaces.count, 1)
        XCTAssertEqual(response.spaces[0].name, "spaces/abc")
        XCTAssertEqual(response.nextPageToken, "token-1")
    }

    func testDecodesMessageListResponse() throws {
        let json = """
        {
          "messages": [
            {
              "name": "spaces/abc/messages/1",
              "text": "hello",
              "createTime": "2026-07-24T12:00:00Z",
              "sender": { "name": "users/1", "displayName": "Alice", "type": "HUMAN" }
            }
          ]
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder.api.decode(ListMessagesResponse.self, from: json)
        XCTAssertEqual(response.messages[0].text, "hello")
        XCTAssertEqual(response.messages[0].sender?.displayName, "Alice")
    }
}
