import XCTest
@testable import GoogleChatCore

final class DeepLinkParserTests: XCTestCase {
    func testParsesSpaceDeepLink() throws {
        let url = URL(string: "gchatmulti://space/spaces%2FAAA")!
        let link = try DeepLinkParser.parse(url)
        XCTAssertEqual(link, .space(resourceName: "spaces/AAA"))
    }
}
