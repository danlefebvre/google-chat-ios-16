import XCTest
@testable import GoogleChatMultiCore

final class ChatModelsTests: XCTestCase {
    func testDecodesSpaceListPayload() throws {
        let json = """
        {
          "spaces": [
            {
              "name": "spaces/AAA",
              "displayName": "#eng-standup",
              "spaceType": "SPACE",
              "lastActiveTime": "2026-07-24T12:00:00Z"
            },
            {
              "name": "spaces/DM1",
              "displayName": "",
              "spaceType": "DIRECT_MESSAGE",
              "lastActiveTime": "2026-07-24T11:00:00Z"
            }
          ]
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder.chat.decode(SpaceListResponse.self, from: json)
        XCTAssertEqual(response.spaces.count, 2)
        XCTAssertEqual(response.spaces[0].resolvedTitle, "#eng-standup")
        XCTAssertTrue(response.spaces[1].isDirectMessage)
        XCTAssertEqual(response.spaces[1].resolvedTitle, "DM")
    }

    func testDecodesMessageListPayload() throws {
        let json = """
        {
          "messages": [
            {
              "name": "spaces/AAA/messages/BBB",
              "text": "deploy looks good",
              "createTime": "2026-07-24T12:00:00Z",
              "sender": { "displayName": "Alice", "name": "users/1" },
              "attachment": [],
              "emojiReactionSummaries": [
                { "emoji": { "unicode": "👍" }, "reactionCount": 2 }
              ]
            }
          ]
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder.chat.decode(MessageListResponse.self, from: json)
        XCTAssertEqual(response.messages[0].text, "deploy looks good")
        XCTAssertEqual(response.messages[0].sender?.displayName, "Alice")
        XCTAssertEqual(response.messages[0].emojiReactionSummaries?.first?.reactionCount, 2)
    }
}
