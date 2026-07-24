import XCTest
@testable import GoogleChatCore

final class AccountIDTests: XCTestCase {
    func testCompositeKeyUsesIssuerAndSubject() {
        let id = AccountID(issuer: "https://accounts.google.com", subject: "12345")
        XCTAssertEqual(id.rawValue, "https://accounts.google.com|12345")
        XCTAssertEqual(id.emailDisplay, nil)
    }

    func testEqualityIgnoresEmail() {
        let a = AccountID(issuer: "iss", subject: "sub", email: "a@example.com")
        let b = AccountID(issuer: "iss", subject: "sub", email: "b@example.com")
        XCTAssertEqual(a, b)
        XCTAssertEqual(a.rawValue, b.rawValue)
    }

    func testParseRawValue() throws {
        let id = try AccountID(rawValue: "https://accounts.google.com|abc")
        XCTAssertEqual(id.issuer, "https://accounts.google.com")
        XCTAssertEqual(id.subject, "abc")
    }

    func testParseRejectsInvalid() {
        XCTAssertThrowsError(try AccountID(rawValue: "no-pipe"))
        XCTAssertThrowsError(try AccountID(rawValue: "|only-sub"))
        XCTAssertThrowsError(try AccountID(rawValue: "only-iss|"))
    }
}
