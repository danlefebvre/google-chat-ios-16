import XCTest
@testable import GoogleChatCore

final class SyncModelsTests: XCTestCase {
    let account = AccountId(issuer: "https://accounts.google.com", sub: "work")
    let merger = MessageMerger()

    func testSyncKeysAreStable() {
        XCTAssertEqual(
            SyncKeys.messageKey(accountId: account, messageName: "spaces/A/messages/B"),
            "\(account.rawValue)::spaces/A/messages/B"
        )
    }

    func testMessageMergerDeduplicatesAndSorts() {
        let t0 = Date(timeIntervalSince1970: 100)
        let t1 = Date(timeIntervalSince1970: 200)
        let existing = [
            ChatMessage(name: "m1", spaceName: "spaces/A", text: "a", senderDisplayName: "A", createTime: t0),
        ]
        let incoming = [
            ChatMessage(name: "m1", spaceName: "spaces/A", text: "a updated", senderDisplayName: "A", createTime: t0),
            ChatMessage(name: "m2", spaceName: "spaces/A", text: "b", senderDisplayName: "B", createTime: t1),
        ]
        let merged = merger.merge(existing: existing, incoming: incoming)
        XCTAssertEqual(merged.count, 2)
        XCTAssertEqual(merged[0].name, "m1")
        XCTAssertEqual(merged[0].text, "a updated")
        XCTAssertEqual(merged[1].name, "m2")
    }
}
