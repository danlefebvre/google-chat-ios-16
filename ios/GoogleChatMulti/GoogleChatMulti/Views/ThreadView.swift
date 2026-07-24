import SwiftUI
import GoogleChatCore

struct ThreadView: View {
    let conversation: ConversationItem
    @EnvironmentObject private var appState: AppState
    @State private var draft = ""
    @State private var messages: [ChatMessage] = []
    @State private var isSending = false

    var body: some View {
        VStack(spacing: 0) {
            List(messages) { message in
                MessageBubble(message: message, isOutgoing: message.senderDisplayName == "You")
            }
            ComposerBar(text: $draft, isSending: isSending) {
                Task { await sendMessage() }
            }
        }
        .navigationTitle(conversation.spaceTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    Text(conversation.spaceTitle)
                    Text(conversation.accountLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .task {
            await loadMessages()
        }
    }

    private func loadMessages() async {
        // Placeholder until OAuth tokens are wired; uses Chat API client.
        messages = []
    }

    private func sendMessage() async {
        guard !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isSending = true
        defer { isSending = false }
        // ChatAPIClient.createMessage wired after OAuth sign-in.
        draft = ""
    }
}

struct MessageBubble: View {
    let message: ChatMessage
    let isOutgoing: Bool

    var body: some View {
        HStack {
            if isOutgoing { Spacer(minLength: 40) }
            VStack(alignment: isOutgoing ? .trailing : .leading, spacing: 4) {
                if !isOutgoing {
                    Text(message.senderDisplayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(message.text)
                    .padding(10)
                    .background(isOutgoing ? Color.accentColor : Color.secondary.opacity(0.15))
                    .foregroundStyle(isOutgoing ? Color.white : Color.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            if !isOutgoing { Spacer(minLength: 40) }
        }
        .listRowSeparator(.hidden)
    }
}

struct ComposerBar: View {
    @Binding var text: String
    let isSending: Bool
    let onSend: () -> Void

    var body: some View {
        HStack {
            TextField("Message", text: $text, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...4)
            Button(action: onSend) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
            }
            .disabled(isSending || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding()
        .background(.bar)
    }
}
