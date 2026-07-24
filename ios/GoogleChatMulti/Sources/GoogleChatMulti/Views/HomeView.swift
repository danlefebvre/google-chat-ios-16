import SwiftUI
import GoogleChatCore

struct RootView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationStack {
            HomeView()
        }
    }
}

struct HomeView: View {
    @EnvironmentObject private var appState: AppState
    @State private var showAccountManager = false

    var body: some View {
        List(appState.filteredConversations) { conversation in
            NavigationLink {
                ThreadView(conversation: conversation)
            } label: {
                ConversationRow(conversation: conversation)
            }
        }
        .navigationTitle("Chat")
        .searchable(text: $appState.searchQuery, prompt: "Search conversations")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                AccountFilterChips(
                    accounts: appState.accounts,
                    selection: $appState.accountFilter
                )
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Accounts") { showAccountManager = true }
            }
        }
        .sheet(isPresented: $showAccountManager) {
            AccountManagerView()
        }
        .onChange(of: appState.pendingDeepLinkConversationId) { conversationId in
            guard conversationId != nil else { return }
            appState.pendingDeepLinkConversationId = nil
        }
    }
}

struct ConversationRow: View {
    let conversation: ConversationSummary

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AccountBadge(label: conversation.accountLabel)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(conversation.title)
                        .font(.headline)
                    Spacer()
                    Text(conversation.lastActivity, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(conversation.lastMessagePreview)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            if conversation.unread {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.vertical, 4)
    }
}

struct AccountBadge: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.caption2.bold())
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.accentColor.opacity(0.2))
            .clipShape(Capsule())
            .accessibilityLabel("Account \(label)")
    }
}

struct AccountFilterChips: View {
    let accounts: [AccountProfile]
    @Binding var selection: AccountFilter

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                FilterChip(title: "All", isSelected: selection == .all) {
                    selection = .all
                }
                ForEach(accounts) { account in
                    FilterChip(
                        title: account.label,
                        isSelected: selection == .account(account.accountId)
                    ) {
                        selection = .account(account.accountId)
                    }
                }
            }
        }
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .buttonStyle(.bordered)
            .tint(isSelected ? .accentColor : .gray)
    }
}
