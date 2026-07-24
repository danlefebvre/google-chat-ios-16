import XCTest
@testable import GoogleChatCore

final class InAppBannerTests: XCTestCase {
    func testBannerTitleIncludesAccountAndSpace() {
        let banner = InAppBanner(
            accountLabel: "Work",
            spaceTitle: "#eng-standup",
            preview: "Alice: hi",
            accountId: AccountID(issuer: "https://accounts.google.com", subject: "1"),
            spaceName: "spaces/A"
        )
        XCTAssertEqual(banner.title, "[Work] #eng-standup")
    }

    func testCenterPresentAndDismiss() {
        let center = InAppBannerCenter()
        var seen: [String?] = []
        center.onChange = { seen.append($0?.id) }
        let banner = InAppBanner(
            id: "b1",
            accountLabel: "Home",
            spaceTitle: "Family",
            preview: "Mom: dinner",
            accountId: AccountID(issuer: "https://accounts.google.com", subject: "2"),
            spaceName: "spaces/B"
        )
        center.present(banner)
        XCTAssertEqual(center.current?.id, "b1")
        center.dismiss()
        XCTAssertNil(center.current)
        XCTAssertEqual(seen, ["b1", nil])
    }
}
