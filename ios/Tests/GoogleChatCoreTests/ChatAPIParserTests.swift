import XCTest
@testable import GoogleChatCore

final class ChatAPIParserTests: XCTestCase {
    func testParsesSpacesListResponse() throws {
        let json = """
        {
          "spaces": [
            {
              "name": "spaces/AAA",
              "displayName": "#eng-standup",
              "type": "SPACE"
            }
          ],
          "nextPageToken": "token-1"
        }
        """.data(using: .utf8)!

        let response = try ChatAPIParser.decodeSpacesList(json)
        XCTAssertEqual(response.spaces.count, 1)
        XCTAssertEqual(response.spaces[0].name, "spaces/AAA")
        XCTAssertEqual(response.nextPageToken, "token-1")
    }

    func testParsesMessagesListResponse() throws {
        let json = """
        {
          "messages": [
            {
              "name": "spaces/AAA/messages/BBB",
              "text": "deploy looks good",
              "createTime": "2026-07-24T12:00:00Z",
              "sender": { "name": "users/1", "displayName": "Alice", "type": "HUMAN" }
            }
          ]
        }
        """.data(using: .utf8)!

        let response = try ChatAPIParser.decodeMessagesList(json)
        XCTAssertEqual(response.messages[0].text, "deploy looks good")
        XCTAssertEqual(response.messages[0].sender?.displayName, "Alice")
    }
}
