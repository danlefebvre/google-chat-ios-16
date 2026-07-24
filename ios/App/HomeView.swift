import SwiftUI
import GoogleChatCore

struct HomeView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        List {
            Section {
                filterChips
                TextField("Search", text: $appModel.searchQuery)
                    .textInputAutocapitalization(.never)
            }

            Section("Inbox") {
                ForEach(appModel.visibleConversations) { conversation in
                    Button {
                        appModel.selectedConversation = conversation
                    } label: {
                        ConversationRow(conversation: conversation)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle("Chat")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink("Accounts") {
                    AccountManagerView()
                }
            }
        }
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                filterButton(title: "All", filter: .all)
                ForEach(appModel.accounts) { account in
                    filterButton(title: account.label, filter: .account(account.id))
                }
            }
        }
    }

    private func filterButton(title: String, filter: InboxFilter) -> some View {
        let selected = appModel.filter == filter
        return Button(title) {
            appModel.filter = filter
        }
        .buttonStyle(.bordered)
        .tint(selected ? .accentColor : .secondary)
    }
}

struct ConversationRow: View {
    let conversation: Conversation

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(conversation.accountLabel)
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color(hex: conversation.badgeColorHex).opacity(0.18))
                .foregroundStyle(Color(hex: conversation.badgeColorHex))
                .clipShape(RoundedRectangle(cornerRadius: 4))

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(conversation.title)
                        .font(.headline)
                        .foregroundStyle(conversation.unread ? .primary : .secondary)
                    Spacer()
                    Text(conversation.lastActivityAt, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(conversation.lastMessagePreview)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }
}
