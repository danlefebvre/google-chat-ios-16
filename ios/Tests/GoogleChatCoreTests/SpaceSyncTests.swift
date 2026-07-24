import XCTest
@testable import GoogleChatCore

final class SpaceSyncTests: XCTestCase {
    func testMapsSpacesToConversationsWithAccountBadge() {
        let account = Account(
            id: AccountID(issuer: "https://accounts.google.com", subject: "work"),
            email: "w@example.com",
            label: "Work",
            badgeColorHex: "#3366FF"
        )
        let spaces = [
            Space(name: "spaces/AAA", displayName: "#eng-standup", spaceType: .space),
            Space(name: "spaces/BBB", displayName: "", spaceType: .directMessage),
        ]
        let convos = SpaceSync.conversations(from: spaces, account: account) { space in
            space.name == "spaces/AAA" ? "Alice: hi" : "Sam: yo"
        }
        XCTAssertEqual(convos.count, 2)
        XCTAssertEqual(convos[0].title, "#eng-standup")
        XCTAssertEqual(convos[0].accountLabel, "Work")
        XCTAssertEqual(convos[0].id.spaceName, "spaces/AAA")
        XCTAssertEqual(convos[1].title, "DM")
    }
}
