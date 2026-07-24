import SwiftUI
import PhotosUI
import GoogleChatCore

struct ThreadView: View {
    @EnvironmentObject private var appModel: AppModel

    let accountID: AccountID
    let spaceName: String
    let title: String
    let accountLabel: String

    @State private var messages: [ChatMessage] = []
    @State private var draft: String = ""
    @State private var isSending = false
    @State private var pickerItem: PhotosPickerItem?
    @State private var status: String?

    private let attachmentPolicy = AttachmentMemoryPolicy.iPhone8

    var body: some View {
        VStack(spacing: 0) {
            accountBanner
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(messages.reversed()) { message in
                            MessageBubble(
                                message: message,
                                onReact: { emoji in
                                    Task { await react(to: message, emoji: emoji) }
                                }
                            )
                            .id(message.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: messages.count) { _ in
                    if let last = messages.first {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }
            composer
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .onChange(of: pickerItem) { item in
            guard let item else { return }
            Task { await uploadPicked(item) }
        }
    }

    private var accountBanner: some View {
        HStack {
            Text("Sending as \(accountLabel)")
                .font(.footnote.weight(.semibold))
            Spacer()
            if let status {
                Text(status).font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.secondary.opacity(0.08))
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 8) {
            PhotosPicker(selection: $pickerItem, matching: .any(of: [.images, .item])) {
                Image(systemName: "paperclip")
            }
            .accessibilityLabel("Attach")

            TextField("Message", text: $draft, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...5)

            Button {
                Task { await send() }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
            }
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
            .accessibilityLabel("Send")
        }
        .padding()
    }

    private func client() -> ChatAPIClient {
        ChatAPIClient {
            let provider = TokenProvider(store: appModel.authStore, refresher: OAuthTokenRefresher())
            return try await provider.validAccessToken(for: accountID)
        }
    }

    private func load() async {
        do {
            let cached = try await appModel.conversationStore.messages(
                accountID: accountID,
                spaceName: spaceName,
                limit: 40,
                before: nil
            )
            messages = cached
            let api = client()
            let page = try await api.listMessages(spaceName: spaceName, pageToken: nil, pageSize: 40)
            let stamped = page.messages.map { msg -> ChatMessage in
                var copy = msg
                copy.accountID = accountID
                return copy
            }
            try await appModel.conversationStore.upsertMessages(stamped)
            messages = try await appModel.conversationStore.messages(
                accountID: accountID,
                spaceName: spaceName,
                limit: 40,
                before: nil
            )
            try await api.markSpaceRead(spaceName: spaceName)
        } catch {
            status = error.localizedDescription
        }
    }

    private func send() async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        isSending = true
        defer { isSending = false }
        do {
            var sent = try await client().sendMessage(spaceName: spaceName, text: text)
            sent.accountID = accountID
            try await appModel.conversationStore.upsertMessages([sent])
            draft = ""
            messages.insert(sent, at: 0)
        } catch {
            status = error.localizedDescription
        }
    }

    private func react(to message: ChatMessage, emoji: String) async {
        do {
            _ = try await client().createReaction(messageName: message.name, emoji: emoji)
            status = "Reacted \(emoji)"
        } catch {
            status = error.localizedDescription
        }
    }

    private func uploadPicked(_ item: PhotosPickerItem) async {
        status = "Attachment selected (upload uses Chat media API; max thumb \(attachmentPolicy.maxThumbnailEdge)px)"
        pickerItem = nil
        // Full media upload requires Google Chat media endpoints + multipart; wired as next integration step.
        _ = attachmentPolicy.maxConcurrentDecodes
    }
}

struct MessageBubble: View {
    let message: ChatMessage
    let onReact: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(message.senderDisplayName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(message.text)
                .padding(10)
                .background(Color.secondary.opacity(0.12))
            if !message.attachmentResourceNames.isEmpty {
                Label("\(message.attachmentResourceNames.count) attachment(s)", systemImage: "paperclip")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            HStack {
                Button("👍") { onReact("👍") }
                Button("🎉") { onReact("🎉") }
                Spacer()
                Text(message.createTime, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
        }
    }
}
