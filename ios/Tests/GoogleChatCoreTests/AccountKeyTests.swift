import XCTest
@testable import GoogleChatCore

final class AccountKeyTests: XCTestCase {
    func testCompositeIdUsesIssuerAndSubject() {
        let key = AccountKey(issuer: "https://accounts.google.com", subject: "12345")
        XCTAssertEqual(key.id, "https://accounts.google.com|12345")
    }

    func testDisplayEmailIsNotUsedAsStableId() {
        let key = AccountKey(issuer: "https://accounts.google.com", subject: "12345", email: "work@example.com")
        XCTAssertEqual(key.id, "https://accounts.google.com|12345")
        XCTAssertEqual(key.email, "work@example.com")
    }
}
