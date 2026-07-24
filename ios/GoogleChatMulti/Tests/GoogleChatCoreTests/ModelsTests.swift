import XCTest
@testable import GoogleChatCore

final class AccountIdTests: XCTestCase {
    func testRawValueRoundTrip() {
        let id = AccountId(issuer: "https://accounts.google.com", sub: "12345")
        XCTAssertEqual(id.rawValue, "https://accounts.google.com|12345")
        XCTAssertEqual(AccountId(rawValue: id.rawValue), id)
    }

    func testInvalidRawValueReturnsNil() {
        XCTAssertNil(AccountId(rawValue: "no-pipe"))
    }
}

final class ConversationIdTests: XCTestCase {
    func testCompositeIdRoundTrip() {
        let accountId = AccountId(issuer: "iss", sub: "sub")
        let conversationId = ConversationId(accountId: accountId, spaceName: "spaces/AAA")
        XCTAssertEqual(conversationId.rawValue, "iss|sub:spaces/AAA")
        XCTAssertEqual(ConversationId(rawValue: conversationId.rawValue), conversationId)
    }

    func testCompositeIdRoundTripWithHTTPSIssuer() {
        let accountId = AccountId(issuer: "https://accounts.google.com", sub: "demo-1")
        let conversationId = ConversationId(accountId: accountId, spaceName: "spaces/demo")
        XCTAssertEqual(
            conversationId.rawValue,
            "https://accounts.google.com|demo-1:spaces/demo"
        )
        XCTAssertEqual(ConversationId(rawValue: conversationId.rawValue), conversationId)
    }
}
