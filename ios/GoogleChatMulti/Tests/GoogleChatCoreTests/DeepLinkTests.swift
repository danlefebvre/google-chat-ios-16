import XCTest
@testable import GoogleChatCore

final class DeepLinkBuilderTests: XCTestCase {
    func testBuildsSpaceDeepLink() {
        let accountId = AccountId(issuer: "iss", sub: "sub")
        let conversationId = ConversationId(accountId: accountId, spaceName: "spaces/AAA")
        let url = DeepLinkBuilder.spaceURL(conversationId: conversationId)
        XCTAssertEqual(url?.absoluteString, "gchatmulti://space/iss%7Csub%3Aspaces%2FAAA")
    }
}
