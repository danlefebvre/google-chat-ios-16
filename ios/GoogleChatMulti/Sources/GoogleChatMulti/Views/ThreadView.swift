import SwiftUI
import GoogleChatCore

struct ThreadView: View {
    let conversation: ConversationSummary
    @State private var draft = ""
    @State private var messages: [ChatMessage] = []

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(messages) { message in
                        MessageBubble(message: message)
                    }
                }
                .padding()
            }
            ComposerBar(text: $draft, accountLabel: conversation.accountLabel) {
                sendMessage()
            }
        }
        .navigationTitle(conversation.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack {
                    Text(conversation.title)
                    Text(conversation.accountLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func sendMessage() {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let message = ChatMessage(
            id: UUID().uuidString,
            spaceName: conversation.conversationId.spaceName,
            senderName: "You",
            text: trimmed,
            createTime: Date(),
            isFromCurrentUser: true
        )
        messages.append(message)
        draft = ""
    }
}

struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.isFromCurrentUser { Spacer(minLength: 40) }
            VStack(alignment: message.isFromCurrentUser ? .trailing : .leading, spacing: 2) {
                if !message.isFromCurrentUser {
                    Text(message.senderName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(message.text)
                    .padding(10)
                    .background(message.isFromCurrentUser ? Color.accentColor.opacity(0.2) : Color.gray.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            if !message.isFromCurrentUser { Spacer(minLength: 40) }
        }
    }
}

struct ComposerBar: View {
    @Binding var text: String
    let accountLabel: String
    let onSend: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text(accountLabel)
                .font(.caption2)
                .foregroundStyle(.secondary)
            TextField("Message", text: $text, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...5)
            Button("Send", action: onSend)
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding()
        .background(.bar)
    }
}
