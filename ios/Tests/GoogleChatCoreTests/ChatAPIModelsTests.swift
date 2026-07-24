import XCTest
@testable import GoogleChatCore

final class ChatAPIModelsTests: XCTestCase {
    func testDecodeSpaceList() throws {
        let json = """
        {
          "spaces": [
            {
              "name": "spaces/AAA",
              "displayName": "#eng-standup",
              "spaceType": "SPACE"
            },
            {
              "name": "spaces/BBB",
              "displayName": "",
              "spaceType": "DIRECT_MESSAGE"
            }
          ],
          "nextPageToken": "tok"
        }
        """.data(using: .utf8)!

        let page = try ChatJSON.makeDecoder().decode(SpaceListResponse.self, from: json)
        XCTAssertEqual(page.spaces.count, 2)
        XCTAssertEqual(page.spaces[0].name, "spaces/AAA")
        XCTAssertEqual(page.spaces[0].displayName, "#eng-standup")
        XCTAssertEqual(page.nextPageToken, "tok")
        XCTAssertEqual(page.spaces[1].spaceType, .directMessage)
    }

    func testDecodeMessageList() throws {
        let json = """
        {
          "messages": [
            {
              "name": "spaces/AAA/messages/BBB",
              "sender": { "name": "users/1", "displayName": "Alice" },
              "text": "deploy looks good",
              "createTime": "2026-07-24T12:00:00Z",
              "attachment": [
                { "name": "spaces/AAA/messages/BBB/attachments/1", "contentName": "shot.png", "contentType": "image/png" }
              ]
            }
          ]
        }
        """.data(using: .utf8)!

        let page = try ChatJSON.makeDecoder().decode(MessageListResponse.self, from: json)
        XCTAssertEqual(page.messages.count, 1)
        XCTAssertEqual(page.messages[0].text, "deploy looks good")
        XCTAssertEqual(page.messages[0].attachments?.first?.contentName, "shot.png")
    }

    func testDecodeEmptyMessageListObject() throws {
        let json = "{}".data(using: .utf8)!
        let page = try ChatJSON.makeDecoder().decode(MessageListResponse.self, from: json)
        XCTAssertEqual(page.messages.count, 0)
        XCTAssertNil(page.nextPageToken)
    }

    func testDecodeUploadAttachmentResponse() throws {
        let json = """
        {
          "attachmentDataRef": {
            "resourceName": "spaces/AAA/attachments/xyz",
            "attachmentUploadToken": "upload-tok"
          }
        }
        """.data(using: .utf8)!
        let resp = try ChatJSON.makeDecoder().decode(UploadAttachmentResponse.self, from: json)
        XCTAssertEqual(resp.attachmentDataRef.resourceName, "spaces/AAA/attachments/xyz")
        XCTAssertEqual(resp.attachmentDataRef.attachmentUploadToken, "upload-tok")
    }
}
