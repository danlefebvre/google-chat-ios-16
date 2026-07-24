import XCTest
@testable import GoogleChatCore

final class DeepLinkTests: XCTestCase {
    func testParseOpenSpaceURL() throws {
        let url = URL(string: "googlechatmulti://open?accountId=iss%7Cwork&space=spaces%2FAAA")!
        let link = try DeepLink(url: url)
        guard case let .openSpace(accountID, space) = link else {
            return XCTFail("unexpected \(link)")
        }
        XCTAssertEqual(accountID.rawValue, "iss|work")
        XCTAssertEqual(space, "spaces/AAA")
    }

    func testRejectsUnknownHost() {
        let url = URL(string: "googlechatmulti://noop")!
        XCTAssertThrowsError(try DeepLink(url: url))
    }

    func testBuildClickURL() {
        let id = AccountID(issuer: "iss", subject: "work")
        let url = DeepLink.openSpaceURL(accountID: id, spaceName: "spaces/AAA")
        XCTAssertEqual(url.scheme, "googlechatmulti")
        XCTAssertEqual(url.host, "open")
        let link = try! DeepLink(url: url)
        guard case let .openSpace(accountID, space) = link else {
            return XCTFail("parse failed")
        }
        XCTAssertEqual(accountID, id)
        XCTAssertEqual(space, "spaces/AAA")
    }
}
