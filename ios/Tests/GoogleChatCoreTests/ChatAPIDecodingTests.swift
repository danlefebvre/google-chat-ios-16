import XCTest
@testable import GoogleChatCore

final class ChatAPIDecodingTests: XCTestCase {
    func testDecodeSpacesList() throws {
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
              "spaceType": "DIRECT_MESSAGE",
              "lastActiveTime": "2026-07-24T11:00:00Z"
            }
          ],
          "nextPageToken": "page-2"
        }
        """.data(using: .utf8)!

        let page = try JSONDecoder.chat.decode(SpacesPage.self, from: json)
        XCTAssertEqual(page.spaces.count, 2)
        XCTAssertEqual(page.spaces[0].name, "spaces/AAA")
        XCTAssertEqual(page.spaces[0].displayName, "#eng-standup")
        XCTAssertEqual(page.spaces[1].spaceType, .directMessage)
        XCTAssertEqual(page.nextPageToken, "page-2")
    }

    func testDecodeMessagesList() throws {
        let json = """
        {
          "messages": [
            {
              "name": "spaces/AAA/messages/BBB",
              "sender": { "name": "users/1", "displayName": "Alice", "type": "HUMAN" },
              "text": "deploy looks good",
              "createTime": "2026-07-24T12:00:00Z",
              "attachment": [
                {
                  "name": "spaces/AAA/messages/BBB/attachments/1",
                  "contentName": "shot.png",
                  "contentType": "image/png",
                  "attachmentDataRef": { "resourceName": "media/xyz" },
                  "thumbnailUri": "https://example.com/thumb.png"
                }
              ],
              "emojiReactionSummaries": [
                { "emoji": { "unicode": "👍" }, "reactionCount": 2 }
              ]
            }
          ]
        }
        """.data(using: .utf8)!

        let page = try JSONDecoder.chat.decode(MessagesPage.self, from: json)
        XCTAssertEqual(page.messages.count, 1)
        let msg = page.messages[0]
        XCTAssertEqual(msg.text, "deploy looks good")
        XCTAssertEqual(msg.sender?.displayName, "Alice")
        XCTAssertEqual(msg.attachments?.count, 1)
        XCTAssertEqual(msg.attachments?.first?.contentName, "shot.png")
        XCTAssertEqual(msg.emojiReactionSummaries?.first?.reactionCount, 2)
    }

    func testCreateMessageBody() throws {
        let body = CreateMessageRequest(text: "hello")
        let data = try JSONEncoder.chat.encode(body)
        let obj = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(obj["text"] as? String, "hello")
    }

    func testReactionBody() throws {
        let body = CreateReactionRequest(emojiUnicode: "🎉")
        let data = try JSONEncoder.chat.encode(body)
        let json = String(data: data, encoding: .utf8)!
        XCTAssertTrue(json.contains("🎉"))
    }

    func testDecodeFractionalSecondTimestamps() throws {
        let json = """
        {
          "spaces": [
            {
              "name": "spaces/AAA",
              "displayName": "#eng",
              "lastActiveTime": "2026-07-24T12:00:00.123Z"
            }
          ]
        }
        """.data(using: .utf8)!

        let page = try JSONDecoder.chat.decode(SpacesPage.self, from: json)
        XCTAssertEqual(page.spaces.count, 1)
        XCTAssertNotNil(page.spaces[0].lastActiveTime)
    }
}
