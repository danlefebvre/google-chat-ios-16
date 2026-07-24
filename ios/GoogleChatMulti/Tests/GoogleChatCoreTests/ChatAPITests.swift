import XCTest
@testable import GoogleChatCore

final class ChatAPIParsingTests: XCTestCase {
    func testMapSpaceUsesDisplayName() {
        let dto = ChatAPIParsing.mapSpace(
            SpaceResource(name: "spaces/AAA", displayName: "#eng-standup", type: "ROOM")
        )
        XCTAssertEqual(dto.displayName, "#eng-standup")
    }

    func testMapMessageDetectsCurrentUser() {
        let message = ChatAPIParsing.mapMessage(
            MessageResource(
                name: "spaces/AAA/messages/BBB",
                text: "hello",
                createTime: "2026-07-24T12:00:00Z",
                sender: MessageSender(name: "users/me", displayName: "You")
            ),
            spaceName: "spaces/AAA",
            currentUserResourceName: "users/me"
        )
        XCTAssertEqual(message?.isFromCurrentUser, true)
        XCTAssertEqual(message?.text, "hello")
    }

    func testParseCreateTimeSupportsFractionalSeconds() {
        let withFraction = ChatAPIParsing.parseCreateTime("2026-07-24T12:00:00.260127Z")
        let withoutFraction = ChatAPIParsing.parseCreateTime("2026-07-24T12:00:00Z")
        XCTAssertNotEqual(withFraction, Date.distantPast)
        XCTAssertNotEqual(withoutFraction, Date.distantPast)
        XCTAssertEqual(
            Calendar.current.compare(withFraction, to: withoutFraction, toGranularity: .second),
            .orderedSame
        )
    }
}
