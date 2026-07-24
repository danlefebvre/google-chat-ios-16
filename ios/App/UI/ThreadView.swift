import SwiftUI
import GoogleChatCore
import PhotosUI

struct ThreadView: View {
    @EnvironmentObject private var model: AppModel
    let conversation: ConversationSummary
    @State private var draft = ""
    @State private var pickerItem: PhotosPickerItem?
    @State private var uploadError: String?

    var body: some View {
        VStack(spacing: 0) {
            accountContextBar
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(model.threadMessages) { message in
                            MessageBubble(
                                message: message,
                                onReact: { emoji in
                                    Task { await model.react(to: message, emoji: emoji) }
                                }
                            )
                            .id(message.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: model.threadMessages.count) { _ in
                    if let last = model.threadMessages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }
            composer
        }
        .navigationTitle(conversation.title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await model.openConversation(conversation)
        }
        .alert("Attachment", isPresented: Binding(
            get: { uploadError != nil },
            set: { if !$0 { uploadError = nil } }
        )) {
            Button("OK", role: .cancel) { uploadError = nil }
        } message: {
            Text(uploadError ?? "")
        }
    }

    private var accountContextBar: some View {
        HStack {
            AccountBadge(label: conversation.accountLabel, colorHex: conversation.badgeColorHex)
            Text("Sending as \(conversation.accountLabel)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.secondary.opacity(0.08))
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 8) {
            PhotosPicker(selection: $pickerItem, matching: .any(of: [.images, .videos])) {
                Image(systemName: "paperclip")
            }
            .onChange(of: pickerItem) { item in
                guard let item else { return }
                Task { await upload(item) }
            }
            TextField("Message", text: $draft, axis: .vertical)
                .lineLimit(1...5)
                .textFieldStyle(.roundedBorder)
            Button {
                let text = draft
                draft = ""
                Task { await model.sendMessage(text) }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
            }
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(10)
    }

    private func upload(_ item: PhotosPickerItem) async {
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else { return }
            guard AttachmentPolicy.allowsUpload(byteCount: data.count) else {
                uploadError = "File exceeds \(AttachmentPolicy.maxUploadBytes / (1024 * 1024)) MB limit"
                return
            }
            let filename = "upload-\(Int(Date().timeIntervalSince1970)).bin"
            try await model.uploadAttachment(
                filename: filename,
                contentType: "application/octet-stream",
                bytes: data
            )
            pickerItem = nil
        } catch {
            uploadError = error.localizedDescription
        }
    }
}

struct MessageBubble: View {
    let message: ChatMessage
    let onReact: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(message.sender?.displayName ?? "Unknown")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(message.text ?? "")
                .padding(10)
                .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
            if let attachments = message.attachments, !attachments.isEmpty {
                ForEach(attachments) { attachment in
                    Label(attachment.contentName ?? "Attachment", systemImage: "doc")
                        .font(.caption)
                }
            }
            if let reactions = message.emojiReactionSummaries, !reactions.isEmpty {
                HStack {
                    ForEach(Array(reactions.enumerated()), id: \.offset) { _, summary in
                        Text("\(summary.emoji?.unicode ?? "") \(summary.reactionCount ?? 0)")
                            .font(.caption2)
                            .padding(4)
                            .background(Color.secondary.opacity(0.1), in: Capsule())
                    }
                }
            }
            HStack {
                Button("👍") { onReact("👍") }
                Button("🎉") { onReact("🎉") }
                Button("❤️") { onReact("❤️") }
            }
            .font(.caption)
            .buttonStyle(.borderless)
        }
    }
}
