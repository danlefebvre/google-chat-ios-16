import XCTest
@testable import GoogleChatCore

final class MediaClientTests: XCTestCase {
    func testAttachmentPlaceholderPreview() {
        let message = ChatMessage(
            name: "spaces/a/messages/1",
            text: nil,
            attachment: [ChatAttachment(name: "files/1", contentName: "photo.png")]
        )
        XCTAssertEqual(MessagePreviewBuilder.preview(for: message), "[attachment] photo.png")
    }

    func testTextPreviewUsesSenderAndBody() {
        let message = ChatMessage(
            name: "spaces/a/messages/2",
            text: "hello",
            sender: ChatUser(displayName: "Alice")
        )
        XCTAssertEqual(MessagePreviewBuilder.preview(for: message), "Alice: hello")
    }
}
