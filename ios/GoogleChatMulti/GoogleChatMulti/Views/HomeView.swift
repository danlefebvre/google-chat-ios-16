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

    var body: some View {
        List(appState.conversations) { item in
            NavigationLink(value: item) {
                ConversationRow(item: item)
            }
        }
        .navigationTitle("Chat")
        .searchable(text: $appState.searchQuery)
        .onChange(of: appState.searchQuery) { _ in appState.refreshInbox() }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink("Accounts") {
                    AccountManagerView()
                }
            }
        }
        .navigationDestination(for: ConversationItem.self) { item in
            ThreadView(conversation: item)
        }
        .safeAreaInset(edge: .top) {
            InboxFilterBar(filter: $appState.inboxFilter) {
                appState.refreshInbox()
            }
        }
    }
}

struct ConversationRow: View {
    let item: ConversationItem

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            AccountBadge(label: item.accountLabel)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.spaceTitle)
                        .font(.headline)
                    Spacer()
                    Text(item.lastActivity, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(item.lastMessagePreview)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            if item.isUnread {
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
        Text(label.prefix(1).uppercased())
            .font(.caption.bold())
            .frame(width: 28, height: 28)
            .background(Color.accentColor.opacity(0.2))
            .clipShape(Circle())
            .accessibilityLabel(label)
    }
}

struct InboxFilterBar: View {
    @Binding var filter: InboxFilter
    let onChange: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                FilterChip(title: "All", selected: isAll) {
                    filter = .all
                    onChange()
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }

    private var isAll: Bool {
        if case .all = filter { return true }
        return false
    }
}

struct FilterChip: View {
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(selected ? Color.accentColor : Color.secondary.opacity(0.15))
                .foregroundStyle(selected ? Color.white : Color.primary)
                .clipShape(Capsule())
        }
    }
}

#Preview {
    NavigationStack {
        HomeView()
            .environmentObject(AppState())
    }
}
