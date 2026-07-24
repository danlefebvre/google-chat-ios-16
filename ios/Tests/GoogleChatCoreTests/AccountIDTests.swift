import XCTest
@testable import GoogleChatCore

final class AccountIDTests: XCTestCase {
    func testCompositeStringUsesIssuerAndSubject() {
        let id = AccountID(issuer: "https://accounts.google.com", subject: "sub-123")
        XCTAssertEqual(id.rawValue, "https://accounts.google.com|sub-123")
    }

    func testParseRoundTrip() throws {
        let raw = "https://accounts.google.com|abc"
        let id = try AccountID(rawValue: raw)
        XCTAssertEqual(id.issuer, "https://accounts.google.com")
        XCTAssertEqual(id.subject, "abc")
        XCTAssertEqual(id.rawValue, raw)
    }

    func testParseRejectsMissingSeparator() {
        XCTAssertThrowsError(try AccountID(rawValue: "no-separator"))
    }

    func testEmailIsDisplayOnlyNotIdentity() {
        let a = Account(
            id: AccountID(issuer: "https://accounts.google.com", subject: "1"),
            email: "old@example.com",
            displayName: "Ada",
            label: "Work",
            badgeColorHex: "#C45C26"
        )
        let b = Account(
            id: a.id,
            email: "new@example.com",
            displayName: "Ada",
            label: "Work",
            badgeColorHex: "#C45C26"
        )
        XCTAssertEqual(a.id, b.id)
        XCTAssertNotEqual(a.email, b.email)
    }
}
