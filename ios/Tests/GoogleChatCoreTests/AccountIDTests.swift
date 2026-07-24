import XCTest
@testable import GoogleChatCore

final class AccountIDTests: XCTestCase {
    func testCompositeKeyUsesIssuerAndSubject() {
        let id = AccountID(issuer: "https://accounts.google.com", subject: "sub-123")
        XCTAssertEqual(id.key, "https://accounts.google.com|sub-123")
    }

    func testEmailIsDisplayOnlyAndNotPartOfIdentity() {
        let a = Account(
            id: AccountID(issuer: "https://accounts.google.com", subject: "sub-1"),
            email: "old@example.com",
            label: "Work",
            badgeColorHex: "#3366FF"
        )
        let b = Account(
            id: AccountID(issuer: "https://accounts.google.com", subject: "sub-1"),
            email: "new@example.com",
            label: "Work",
            badgeColorHex: "#3366FF"
        )
        XCTAssertEqual(a.id, b.id)
        XCTAssertNotEqual(a.email, b.email)
    }

    func testParseKeyRoundTrip() throws {
        let original = AccountID(issuer: "https://accounts.google.com", subject: "abc")
        let parsed = try AccountID(key: original.key)
        XCTAssertEqual(parsed, original)
    }
}
