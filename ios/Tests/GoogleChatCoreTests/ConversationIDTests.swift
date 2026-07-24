import XCTest
@testable import GoogleChatCore

final class ConversationIDTests: XCTestCase {
    func testStableCompositeUsesAccountAndSpaceResourceName() {
        let account = AccountID(issuer: "https://accounts.google.com", subject: "work")
        let id = ConversationID(accountID: account, spaceName: "spaces/AAA")
        XCTAssertEqual(id.rawValue, "https://accounts.google.com|work:spaces/AAA")
    }

    func testRenamedSpaceTitleDoesNotChangeID() {
        let account = AccountID(issuer: "https://accounts.google.com", subject: "work")
        let before = Conversation(
            id: ConversationID(accountID: account, spaceName: "spaces/AAA"),
            title: "Old name",
            lastMessagePreview: "hi",
            lastActivityAt: Date(timeIntervalSince1970: 1),
            unread: false,
            accountLabel: "Work",
            badgeColorHex: "#3366FF"
        )
        let after = Conversation(
            id: ConversationID(accountID: account, spaceName: "spaces/AAA"),
            title: "New name",
            lastMessagePreview: "hi",
            lastActivityAt: Date(timeIntervalSince1970: 1),
            unread: false,
            accountLabel: "Work",
            badgeColorHex: "#3366FF"
        )
        XCTAssertEqual(before.id, after.id)
    }

    func testRawValueRoundTripWithHTTPSIssuer() {
        let account = AccountID(issuer: "https://accounts.google.com", subject: "work")
        let id = ConversationID(accountID: account, spaceName: "spaces/AAA")
        let parsed = ConversationID(rawValue: id.rawValue)
        XCTAssertEqual(parsed, id)
    }
}
