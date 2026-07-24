import SwiftUI
import GoogleChatCore

struct ThreadView: View {
    @EnvironmentObject private var model: AppModel
    let conversation: ConversationRow

    @State private var draft = ""
    @State private var messages: [ChatMessage] = []

    var body: some View {
        VStack(spacing: 0) {
            accountBanner
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(messages) { message in
                        MessageBubble(message: message)
                    }
                }
                .padding()
            }
            composer
        }
        .navigationTitle(conversation.title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadMessages()
        }
    }

    private var accountBanner: some View {
        HStack {
            AccountBadge(label: conversation.accountLabel, color: conversation.accountColor)
            Text("Sending as \(conversation.accountLabel)")
                .font(.footnote)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.1))
    }

    private var composer: some View {
        HStack {
            TextField("Message", text: $draft, axis: .vertical)
                .textFieldStyle(.roundedBorder)
            Button("Send") {
                let text = draft
                draft = ""
                Task {
                    await model.sendMessage(text: text, in: conversation)
                    await loadMessages()
                }
            }
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding()
    }

    private func loadMessages() async {
        guard let account = model.accounts.first(where: { $0.id == conversation.accountKey.id }) else {
            return
        }
        do {
            let response = try await ChatAPIClient().listMessages(
                spaceResourceName: conversation.spaceResourceName,
                accessToken: account.accessToken
            )
            messages = response.messages.reversed()
        } catch {
            model.errorMessage = error.localizedDescription
        }
    }
}

private struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(message.sender?.displayName ?? "Unknown")
                .font(.caption.weight(.semibold))
            Text(message.text ?? "")
                .font(.body)
                .padding(10)
                .background(Color.blue.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
