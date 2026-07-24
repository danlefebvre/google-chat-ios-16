import SwiftUI
import GoogleChatMultiCore
import PhotosUI

struct ThreadView: View {
    @EnvironmentObject private var model: AppModel
    let compositeId: String

    @State private var messages: [ChatMessage] = []
    @State private var draft = ""
    @State private var isSending = false
    @State private var loadError: String?
    @State private var pickerItem: PhotosPickerItem?

    private var conversation: ConversationSummary? {
        model.conversations.first { $0.compositeId == compositeId }
    }

    var body: some View {
        VStack(spacing: 0) {
            if let loadError {
                Text(loadError)
                    .foregroundStyle(.red)
                    .padding()
            }
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(messages.reversed()) { message in
                            MessageBubble(message: message) {
                                await react(to: message, unicode: "👍")
                            }
                            .id(message.id)
                        }
                    }
                    .padding(16)
                }
                .onChange(of: messages.count) { _ in
                    if let last = messages.reversed().first?.id {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(last, anchor: .bottom)
                        }
                    }
                }
            }

            ComposerBar(
                draft: $draft,
                isSending: isSending,
                onSend: send,
                pickerItem: $pickerItem
            )
        }
        .navigationTitle(conversation?.title ?? "Thread")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    Text(conversation?.title ?? "Thread")
                        .font(.headline)
                    if let conversation {
                        Text("Sending as \(conversation.accountLabel)")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color(hex: conversation.accountColorHex) ?? .secondary)
                    }
                }
            }
        }
        .task { await load() }
        .onChange(of: pickerItem) { item in
            guard let item else { return }
            Task { await uploadAttachment(item) }
        }
        .background(Color("CanvasBackground").ignoresSafeArea())
    }

    private func load() async {
        guard let conversation,
              let api = await apiClient()
        else { return }
        do {
            let response = try await api.listMessages(
                accountId: conversation.accountId,
                spaceName: conversation.spaceName,
                pageSize: 40
            )
            messages = response.messages
            try? await api.markSpaceRead(
                accountId: conversation.accountId,
                spaceName: conversation.spaceName
            )
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func send() async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let conversation, let api = await apiClient() else { return }
        isSending = true
        defer { isSending = false }
        do {
            let message = try await api.sendMessage(
                accountId: conversation.accountId,
                spaceName: conversation.spaceName,
                text: text
            )
            messages.insert(message, at: 0)
            draft = ""
        } catch {
            model.banner = "Send failed."
        }
    }

    private func react(to message: ChatMessage, unicode: String) async {
        guard let conversation, let api = await apiClient() else { return }
        do {
            try await api.addReaction(
                accountId: conversation.accountId,
                messageName: message.name,
                unicode: unicode
            )
            await load()
        } catch {
            model.banner = "Reaction failed."
        }
    }

    private func uploadAttachment(_ item: PhotosPickerItem) async {
        guard let conversation else { return }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else { return }
            let limited = AttachmentMemory.limitImageData(data, maxBytes: 1_500_000)
            // MVP: send a note that an attachment was selected; full media upload uses Chat media API.
            draft = draft.isEmpty
                ? "[Attachment ready: \(limited.count) bytes — upload via media API next]"
                : draft
            pickerItem = nil
            _ = conversation
        } catch {
            model.banner = "Could not load attachment."
        }
    }

    private func apiClient() async -> ChatAPIClient? {
        ChatAPIClient(tokens: model.authStore.asTokenProvider())
    }
}

struct MessageBubble: View {
    let message: ChatMessage
    let onReact: () async -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(message.sender?.displayName ?? "Someone")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color("SecondaryText"))
            Text(message.text ?? "(attachment)")
                .font(.body)
                .padding(10)
                .background(Color("BubbleFill"))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            if let reactions = message.emojiReactionSummaries, !reactions.isEmpty {
                HStack {
                    ForEach(Array(reactions.enumerated()), id: \.offset) { _, reaction in
                        Text("\(reaction.emoji?.unicode ?? "") \(reaction.reactionCount ?? 0)")
                            .font(.caption2)
                    }
                }
            }
            Button("👍") {
                Task { await onReact() }
            }
            .font(.caption)
            .buttonStyle(.borderless)
        }
    }
}

struct ComposerBar: View {
    @Binding var draft: String
    let isSending: Bool
    let onSend: () async -> Void
    @Binding var pickerItem: PhotosPickerItem?

    var body: some View {
        HStack(spacing: 10) {
            PhotosPicker(selection: $pickerItem, matching: .images) {
                Image(systemName: "paperclip")
            }
            TextField("Message", text: $draft, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...4)
            Button {
                Task { await onSend() }
            } label: {
                if isSending {
                    ProgressView()
                } else {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                }
            }
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
        }
        .padding(12)
        .background(.ultraThinMaterial)
    }
}
