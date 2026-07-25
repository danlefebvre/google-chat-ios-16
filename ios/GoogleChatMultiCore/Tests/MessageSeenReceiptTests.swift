import XCTest
@testable import GoogleChatMultiCore

final class MessageSeenReceiptTests: XCTestCase {
    private let me = "users/me"
    private let peer = "users/peer"

    func testLastSeenIsNewestSelfMessageAtOrBeforePeerReadTime() {
        let t1 = Date(timeIntervalSince1970: 1_000)
        let t2 = Date(timeIntervalSince1970: 2_000)
        let t3 = Date(timeIntervalSince1970: 3_000)
        let messages = [
            ChatMessage(name: "m3", text: "later", createTime: t3, sender: ChatSender(name: me)),
            ChatMessage(name: "m2", text: "mid", createTime: t2, sender: ChatSender(name: me)),
            ChatMessage(name: "m1", text: "early", createTime: t1, sender: ChatSender(name: me)),
        ]

        let seen = MessageSeenReceipt.lastSeenSelfMessageName(
            in: messages,
            selfUserName: me,
            peerLastReadTime: t2
        )

        XCTAssertEqual(seen, "m2")
    }

    func testLastSeenNilWhenPeerHasNotReadAnySelfMessage() {
        let t1 = Date(timeIntervalSince1970: 1_000)
        let messages = [
            ChatMessage(name: "m1", text: "hi", createTime: t1, sender: ChatSender(name: me)),
        ]

        let seen = MessageSeenReceipt.lastSeenSelfMessageName(
            in: messages,
            selfUserName: me,
            peerLastReadTime: Date(timeIntervalSince1970: 500)
        )

        XCTAssertNil(seen)
    }

    func testLastSeenNilWithoutPeerReadTime() {
        let messages = [
            ChatMessage(
                name: "m1",
                text: "hi",
                createTime: Date(timeIntervalSince1970: 1_000),
                sender: ChatSender(name: me)
            ),
        ]
        XCTAssertNil(
            MessageSeenReceipt.lastSeenSelfMessageName(
                in: messages,
                selfUserName: me,
                peerLastReadTime: nil
            )
        )
    }

    func testInferredPeerLastReadTimeUsesNewestPeerMessage() {
        let t1 = Date(timeIntervalSince1970: 1_000)
        let t2 = Date(timeIntervalSince1970: 2_000)
        let t3 = Date(timeIntervalSince1970: 3_000)
        let messages = [
            ChatMessage(name: "m3", text: "you", createTime: t3, sender: ChatSender(name: me)),
            ChatMessage(name: "m2", text: "peer-late", createTime: t2, sender: ChatSender(name: peer)),
            ChatMessage(name: "m1", text: "peer-early", createTime: t1, sender: ChatSender(name: peer)),
        ]

        XCTAssertEqual(
            MessageSeenReceipt.inferredPeerLastReadTime(in: messages, selfUserName: me),
            t2
        )
    }

    func testInferredPeerLastReadTimeNilWhenOnlySelfMessages() {
        let messages = [
            ChatMessage(
                name: "m1",
                text: "hi",
                createTime: Date(timeIntervalSince1970: 1_000),
                sender: ChatSender(name: me)
            ),
        ]
        XCTAssertNil(MessageSeenReceipt.inferredPeerLastReadTime(in: messages, selfUserName: me))
    }

    func testEndToEndReplyHeuristicMarksOnlyLastSeenSelfMessage() {
        let t1 = Date(timeIntervalSince1970: 1_000)
        let t2 = Date(timeIntervalSince1970: 2_000)
        let t3 = Date(timeIntervalSince1970: 3_000)
        let t4 = Date(timeIntervalSince1970: 4_000)
        let messages = [
            ChatMessage(name: "m4", text: "unseen", createTime: t4, sender: ChatSender(name: me)),
            ChatMessage(name: "m3", text: "reply", createTime: t3, sender: ChatSender(name: peer)),
            ChatMessage(name: "m2", text: "seen", createTime: t2, sender: ChatSender(name: me)),
            ChatMessage(name: "m1", text: "older", createTime: t1, sender: ChatSender(name: me)),
        ]

        let peerRead = MessageSeenReceipt.inferredPeerLastReadTime(in: messages, selfUserName: me)
        let seen = MessageSeenReceipt.lastSeenSelfMessageName(
            in: messages,
            selfUserName: me,
            peerLastReadTime: peerRead
        )

        XCTAssertEqual(seen, "m2")
    }
}
