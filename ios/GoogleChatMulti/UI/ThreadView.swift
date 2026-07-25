import SwiftUI
import GoogleChatMultiCore
import PhotosUI

struct ThreadView: View {
    @EnvironmentObject private var model: AppModel
    let compositeId: String

    @State private var messages: [ChatMessage] = []
    @State private var memberNames: [String: String] = [:]
    @State private var selfUserName: String?
    @State private var draft = ""
    @State private var isSending = false
    @State private var loadError: String?
    @State private var pickerItem: PhotosPickerItem?
    @State private var nextPageToken: String?
    @State private var isLoadingOlder = false
    /// Scroll to the newest bubble after initial load / send.
    @State private var scrollToNewestRequested = false
    /// Keep the previously oldest bubble in place after prepending an older page.
    @State private var preserveScrollMessageId: String?

    private var conversation: ConversationSummary? {
        model.conversations.first { $0.compositeId == compositeId }
    }

    private var hasMoreOlder: Bool {
        MessageHistoryPager.hasMorePages(nextPageToken: nextPageToken)
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
                    LazyVStack(spacing: 10) {
                        if hasMoreOlder || isLoadingOlder {
                            HStack {
                                Spacer()
                                ProgressView()
                                    .opacity(isLoadingOlder ? 1 : 0)
                                Spacer()
                            }
                            .frame(height: 36)
                            .onAppear {
                                Task { await loadOlderMessages() }
                            }
                        }

                        ForEach(messages.reversed()) { message in
                            MessageBubble(
                                message: message,
                                senderLabel: senderLabel(for: message),
                                isFromSelf: isFromSelf(message),
                                accountId: conversation?.accountId,
                                tokenProvider: model.authStore.asTokenProvider(),
                                onReact: { unicode in
                                    await react(to: message, unicode: unicode)
                                }
                            )
                            .id(message.id)
                        }
                    }
                    .padding(16)
                }
                .onChange(of: messages.count) { _ in
                    if scrollToNewestRequested, let newest = messages.first?.id {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(newest, anchor: .bottom)
                        }
                        scrollToNewestRequested = false
                    } else if let preserveScrollMessageId {
                        proxy.scrollTo(preserveScrollMessageId, anchor: .top)
                        self.preserveScrollMessageId = nil
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
        .toolbarBackground(Color.white, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .task { await load() }
        .onChange(of: pickerItem) { item in
            guard let item else { return }
            Task { await uploadAttachment(item) }
        }
        .background(Color("CanvasBackground").ignoresSafeArea())
    }

    private func load(scrollToNewest: Bool = true) async {
        guard let conversation,
              let api = await apiClient()
        else { return }
        let people = PeopleClient(tokens: model.authStore.asTokenProvider())
        let me = conversation.accountId.chatUserName
        selfUserName = me
        memberNames[me] = "You"
        isLoadingOlder = false
        nextPageToken = nil
        scrollToNewestRequested = false
        preserveScrollMessageId = nil

        do {
            var map = memberNames
            var candidateUserNames = Set<String>([me])

            if let members = try? await api.listMembers(
                accountId: conversation.accountId,
                spaceName: conversation.spaceName,
                showInvited: true
            ) {
                for membership in members.memberships {
                    guard let member = membership.member, let name = member.name else { continue }
                    candidateUserNames.insert(name)
                    if member.hasHumanReadableName,
                       let label = member.displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
                    {
                        map[name] = label
                    }
                }
            }

            let response = try await api.listMessages(
                accountId: conversation.accountId,
                spaceName: conversation.spaceName,
                pageSize: 40
            )
            candidateUserNames.formUnion(response.messages.compactMap(\.sender?.name))

            // Chat user-auth responses often omit displayName — fill via People API.
            let unresolved = Array(candidateUserNames.filter { map[$0] == nil && $0 != me })
            if let resolved = try? await people.displayNames(
                accountId: conversation.accountId,
                chatUserNames: unresolved
            ) {
                for (key, value) in resolved where key != me {
                    map[key] = value
                }
            }
            map[me] = "You"
            memberNames = map
            nextPageToken = response.nextPageToken
            scrollToNewestRequested = scrollToNewest && !response.messages.isEmpty
            messages = response.messages
            do {
                try await api.markSpaceRead(
                    accountId: conversation.accountId,
                    spaceName: conversation.spaceName
                )
                model.clearUnread(for: conversation.compositeId)
            } catch {
                // Keep unread styling until mark-read or a later inbox refresh succeeds.
            }
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func loadOlderMessages() async {
        guard !isLoadingOlder,
              let pageToken = nextPageToken,
              MessageHistoryPager.hasMorePages(nextPageToken: pageToken),
              let conversation,
              let api = await apiClient()
        else { return }

        isLoadingOlder = true
        // Newest-first storage: last element is the oldest currently loaded bubble.
        let anchorId = messages.last?.id
        defer { isLoadingOlder = false }

        do {
            let response = try await api.listMessages(
                accountId: conversation.accountId,
                spaceName: conversation.spaceName,
                pageSize: 40,
                pageToken: pageToken
            )
            await resolveSenderNames(for: response.messages, accountId: conversation.accountId)

            let previousCount = messages.count
            let merged = MessageHistoryPager.mergingOlderPage(messages, olderPage: response.messages)
            nextPageToken = response.nextPageToken
            if merged.count > previousCount, let anchorId {
                preserveScrollMessageId = anchorId
            }
            messages = merged
        } catch {
            // Keep the current page token so scrolling up can retry.
            model.banner = "Couldn’t load older messages."
        }
    }

    private func resolveSenderNames(for page: [ChatMessage], accountId: AccountID) async {
        let me = accountId.chatUserName
        let unresolved = page.compactMap(\.sender?.name).filter { memberNames[$0] == nil && $0 != me }
        guard !unresolved.isEmpty else { return }
        let people = PeopleClient(tokens: model.authStore.asTokenProvider())
        guard let resolved = try? await people.displayNames(
            accountId: accountId,
            chatUserNames: unresolved
        ) else { return }
        for (key, value) in resolved where key != me {
            memberNames[key] = value
        }
    }

    private func isFromSelf(_ message: ChatMessage) -> Bool {
        guard let sender = message.sender?.name else { return false }
        if let selfUserName, sender == selfUserName { return true }
        if let me = conversation?.accountId.chatUserName, sender == me { return true }
        return false
    }

    private func senderLabel(for message: ChatMessage) -> String {
        if isFromSelf(message) { return "You" }
        if let name = message.sender?.name, let mapped = memberNames[name], !mapped.isEmpty {
            return mapped
        }
        if let sender = message.sender, sender.hasHumanReadableName {
            return sender.resolvedDisplayName
        }
        return "Someone"
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
            if let senderName = message.sender?.name {
                selfUserName = senderName
                memberNames[senderName] = "You"
            }
            scrollToNewestRequested = true
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
            await load(scrollToNewest: false)
        } catch {
            model.banner = "Reaction failed."
        }
    }

    private func uploadAttachment(_ item: PhotosPickerItem) async {
        guard let conversation, let api = await apiClient() else { return }
        isSending = true
        defer {
            isSending = false
            pickerItem = nil
        }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else { return }
            let limited = AttachmentMemory.limitImageData(data, maxBytes: 1_500_000)
            let uploaded = try await api.uploadAttachment(
                accountId: conversation.accountId,
                spaceName: conversation.spaceName,
                filename: "photo.jpg",
                mimeType: "image/jpeg",
                data: limited
            )
            guard let token = uploaded.attachmentUploadToken else {
                model.banner = "Upload succeeded but no attachment token returned."
                return
            }
            let caption = draft.trimmingCharacters(in: .whitespacesAndNewlines)
            let message = try await api.sendMessage(
                accountId: conversation.accountId,
                spaceName: conversation.spaceName,
                text: caption.isEmpty ? "📷" : caption,
                attachmentUploadTokens: [token]
            )
            scrollToNewestRequested = true
            messages.insert(message, at: 0)
            draft = ""
        } catch {
            model.banner = "Attachment upload failed."
        }
    }

    private func apiClient() async -> ChatAPIClient? {
        ChatAPIClient(tokens: model.authStore.asTokenProvider())
    }
}

/// Quick reactions aligned with Google Chat’s common set (API accepts any unicode emoji).
enum ChatQuickReactions {
    static let all: [String] = ["👍", "😂", "🎉", "❤️", "😮", "😢", "🙏", "🔥"]
}

struct MessageBubble: View {
    let message: ChatMessage
    let senderLabel: String
    let isFromSelf: Bool
    let accountId: AccountID?
    let tokenProvider: (any TokenProviding)?
    let onReact: (String) async -> Void

    private var textBody: String? {
        let trimmed = message.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private var attachments: [ChatAttachment] {
        message.attachment ?? []
    }

    var body: some View {
        HStack {
            if isFromSelf { Spacer(minLength: 48) }

            VStack(alignment: isFromSelf ? .trailing : .leading, spacing: 4) {
                Text(senderLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color("SecondaryText"))

                VStack(alignment: .leading, spacing: 8) {
                    if let textBody {
                        Text(textBody)
                            .font(.body)
                            .foregroundStyle(isFromSelf ? Color.white : Color("PrimaryText"))
                    } else if attachments.isEmpty {
                        Text("(empty message)")
                            .font(.body)
                            .foregroundStyle(isFromSelf ? Color.white.opacity(0.85) : .secondary)
                    }

                    ForEach(Array(attachments.enumerated()), id: \.offset) { _, attachment in
                        if attachment.isImage,
                           let accountId,
                           let tokenProvider,
                           attachment.mediaResourceName != nil
                        {
                            AttachmentImageView(
                                attachment: attachment,
                                accountId: accountId,
                                tokenProvider: tokenProvider
                            )
                        } else {
                            Label(
                                attachment.contentName ?? "Attachment",
                                systemImage: attachment.isImage ? "photo" : "paperclip"
                            )
                            .font(.caption)
                            .foregroundStyle(isFromSelf ? Color.white.opacity(0.9) : Color("SecondaryText"))
                        }
                    }
                }
                .padding(10)
                .background(isFromSelf ? Color.accentColor : Color("BubbleFill"))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                if let reactions = message.emojiReactionSummaries, !reactions.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(Array(reactions.enumerated()), id: \.offset) { _, reaction in
                            let emoji = reaction.emoji?.unicode ?? ""
                            Button {
                                guard !emoji.isEmpty else { return }
                                Task { await onReact(emoji) }
                            } label: {
                                Text("\(emoji) \(reaction.reactionCount ?? 0)")
                                    .font(.caption2)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color("ChipFill"))
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }

                Menu {
                    ForEach(ChatQuickReactions.all, id: \.self) { emoji in
                        Button(emoji) {
                            Task { await onReact(emoji) }
                        }
                    }
                } label: {
                    Label("React", systemImage: "face.smiling")
                        .font(.caption)
                        .foregroundStyle(Color("SecondaryText"))
                }
            }

            if !isFromSelf { Spacer(minLength: 48) }
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
