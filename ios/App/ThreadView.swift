import SwiftUI
import GoogleChatCore

struct ThreadView: View {
    let conversation: Conversation
    @State private var draft = ""
    @State private var messages: [ChatMessage] = []

    var body: some View {
        VStack(spacing: 0) {
            List(messages) { message in
                VStack(alignment: .leading, spacing: 4) {
                    Text(message.sender?.displayName ?? "Unknown")
                        .font(.caption.weight(.semibold))
                    Text(message.text ?? "")
                    if let attachments = message.attachments, !attachments.isEmpty {
                        Text(attachments.map { $0.contentName ?? "file" }.joined(separator: ", "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .listStyle(.plain)

            HStack {
                TextField("Message", text: $draft)
                Button("Send") {
                    send()
                }
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
        }
        .navigationTitle(conversation.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 0) {
                    Text(conversation.title).font(.headline)
                    Text(conversation.accountLabel)
                        .font(.caption2)
                        .foregroundStyle(Color(hex: conversation.badgeColorHex))
                }
            }
        }
        .task {
            if messages.isEmpty {
                messages = [
                    ChatMessage(
                        name: "\(conversation.id.spaceName)/messages/1",
                        sender: ChatUser(displayName: "Alice"),
                        text: conversation.lastMessagePreview,
                        createTime: conversation.lastActivityAt
                    )
                ]
            }
        }
    }

    private func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        messages.append(
            ChatMessage(
                name: "\(conversation.id.spaceName)/messages/\(UUID().uuidString)",
                sender: ChatUser(displayName: "You"),
                text: text,
                createTime: Date()
            )
        )
        draft = ""
    }
}
