import XCTest
@testable import GoogleChatCore

final class DeepLinkTests: XCTestCase {
    func testParsesSpaceDeepLink() throws {
        let url = URL(string: "gchatmulti://space/spaces%2Fabc123")!
        let link = try DeepLink(url: url)
        XCTAssertEqual(link, .space(resourceName: "spaces/abc123"))
    }

    func testBuildsSpaceDeepLink() {
        let url = DeepLink.space(resourceName: "spaces/abc123").url(scheme: "gchatmulti")
        XCTAssertEqual(url.absoluteString, "gchatmulti://space/spaces%2Fabc123")
    }

    func testRejectsUnknownHost() {
        let url = URL(string: "gchatmulti://unknown/foo")!
        XCTAssertThrowsError(try DeepLink(url: url))
    }
}
