import XCTest
@testable import GoogleChatCore

final class DeepLinkTests: XCTestCase {
    func testParseSpaceDeepLink() throws {
        let url = URL(string: "googlechatmulti://space?account=https%3A%2F%2Faccounts.google.com%7Cwork&space=spaces%2FAAA")!
        let link = try DeepLink.parse(url)
        guard case let .space(accountID, spaceName) = link else {
            return XCTFail("expected space link")
        }
        XCTAssertEqual(accountID.key, "https://accounts.google.com|work")
        XCTAssertEqual(spaceName, "spaces/AAA")
    }

    func testBuildSpaceDeepLink() {
        let account = AccountID(issuer: "https://accounts.google.com", subject: "work")
        let url = DeepLink.space(accountID: account, spaceName: "spaces/AAA").url
        XCTAssertEqual(url.scheme, "googlechatmulti")
        XCTAssertEqual(url.host, "space")
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        XCTAssertEqual(items.first(where: { $0.name == "account" })?.value, account.key)
        XCTAssertEqual(items.first(where: { $0.name == "space" })?.value, "spaces/AAA")
    }
}
