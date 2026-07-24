import XCTest
@testable import GoogleChatCore

final class AccountIdTests: XCTestCase {
    func testCompositeKeyUsesIssuerAndSubject() {
        let id = AccountId(issuer: "https://accounts.google.com", subject: "12345")
        XCTAssertEqual(id.rawValue, "https://accounts.google.com|12345")
    }

    func testDisplayEmailIsNotUsedAsIdentity() {
        let id = AccountId(issuer: "https://accounts.google.com", subject: "12345", displayEmail: "alice@example.com")
        XCTAssertEqual(id.displayEmail, "alice@example.com")
        XCTAssertNotEqual(id.rawValue, "alice@example.com")
    }

    func testParsesFromRawValue() throws {
        let id = try AccountId(rawValue: "https://accounts.google.com|12345")
        XCTAssertEqual(id.issuer, "https://accounts.google.com")
        XCTAssertEqual(id.subject, "12345")
    }

    func testInvalidRawValueThrows() {
        XCTAssertThrowsError(try AccountId(rawValue: "missing-separator"))
    }
}
