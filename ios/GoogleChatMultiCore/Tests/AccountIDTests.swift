import XCTest
@testable import GoogleChatMultiCore

final class AccountIDTests: XCTestCase {
    func testCompositeKeyFromIssuerAndSubject() {
        let id = AccountID(issuer: "https://accounts.google.com", subject: "sub-work")
        XCTAssertEqual(id.rawValue, "https://accounts.google.com|sub-work")
        XCTAssertEqual(id.issuer, "https://accounts.google.com")
        XCTAssertEqual(id.subject, "sub-work")
    }

    func testRoundTripParsing() throws {
        let original = AccountID(issuer: "https://accounts.google.com", subject: "abc123")
        let parsed = try AccountID.parse(original.rawValue)
        XCTAssertEqual(parsed, original)
    }

    func testRejectsInvalidRawValue() {
        XCTAssertThrowsError(try AccountID.parse("no-separator"))
    }

    func testEmailIsDisplayOnly() {
        let account = LinkedAccount(
            id: AccountID(issuer: "https://accounts.google.com", subject: "1"),
            email: "you@work.com",
            label: "Work",
            colorHex: "#C45C26"
        )
        XCTAssertEqual(account.displayLabel, "Work")
        XCTAssertEqual(account.email, "you@work.com")
        XCTAssertEqual(account.id.subject, "1")
    }
}
