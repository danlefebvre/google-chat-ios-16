import SwiftUI
import GoogleChatCore

struct ThreadView: View {
    @EnvironmentObject private var appModel: AppModel
    let conversation: ConversationSnapshot

    @State private var messages: [ChatMessage] = []
    @State private var draft = ""
    @State private var isSending = false

    private var account: StoredAccount? {
        appModel.accounts.first { $0.accountId == conversation.accountId }
    }

    var body: some View {
        VStack(spacing: 0) {
            if let account {
                HStack {
                    AccountBadge(label: account.label, color: account.color)
                    Text(conversation.title)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.secondary.opacity(0.08))
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(messages) { message in
                        MessageBubble(message: message, isOutgoing: false)
                    }
                }
                .padding()
            }

            HStack(spacing: 8) {
                TextField("Message", text: $draft, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1 ... 4)

                Button {
                    Task { await send() }
                } label: {
                    if isSending {
                        ProgressView()
                    } else {
                        Image(systemName: "paperplane.fill")
                    }
                }
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
            }
            .padding()
        }
        .navigationTitle(conversation.title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadMessages()
            if let account {
                try? await appModel.markRead(account: account, spaceResourceName: conversation.spaceResourceName)
            }
        }
    }

    private func loadMessages() async {
        guard let account else { return }
        do {
            let response = try await appModel.api.listMessages(
                accessToken: account.accessToken,
                spaceName: conversation.spaceResourceName
            )
            messages = response.messages.reversed()
        } catch {
            appModel.errorMessage = error.localizedDescription
        }
    }

    private func send() async {
        guard let account else { return }
        isSending = true
        defer { isSending = false }

        do {
            let message = try await appModel.sendMessage(
                account: account,
                spaceResourceName: conversation.spaceResourceName,
                text: draft
            )
            messages.append(message)
            draft = ""
        } catch {
            appModel.errorMessage = error.localizedDescription
        }
    }
}

private struct MessageBubble: View {
    let message: ChatMessage
    let isOutgoing: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(message.sender?.displayName ?? "Someone")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if let text = message.text, !text.isEmpty {
                Text(text)
                    .padding(10)
                    .background(Color.secondary.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else if let attachment = message.attachment?.first {
                Label(attachment.contentName ?? "Attachment", systemImage: "paperclip")
                    .font(.subheadline)
                    .padding(10)
                    .background(Color.secondary.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .frame(maxWidth: .infinity, alignment: isOutgoing ? .trailing : .leading)
    }
}
