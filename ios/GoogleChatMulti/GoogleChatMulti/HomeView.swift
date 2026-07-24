import SwiftUI
import GoogleChatCore

struct HomeView: View {
    @EnvironmentObject private var appModel: AppModel

    private var filterLabels: [String] {
        Array(Set(appModel.accounts.map(\.label))).sorted()
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    FilterChip(title: "All", isSelected: appModel.selectedFilter == nil) {
                        appModel.selectedFilter = nil
                    }
                    ForEach(filterLabels, id: \.self) { label in
                        FilterChip(title: label, isSelected: appModel.selectedFilter == label) {
                            appModel.selectedFilter = label
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }

            SearchBar(text: $appModel.searchQuery)

            List(appModel.filteredConversations) { conversation in
                NavigationLink {
                    ThreadView(conversation: conversation)
                } label: {
                    ConversationRowView(conversation: conversation)
                }
            }
            .listStyle(.plain)
            .overlay {
                if appModel.isLoading && appModel.conversations.isEmpty {
                    ProgressView("Loading chats…")
                } else if appModel.filteredConversations.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "message")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("No conversations")
                            .font(.headline)
                        Text("Add a Google account to get started.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .refreshable {
                await appModel.refresh()
            }
        }
    }
}

private struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.12))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct SearchBar: View {
    @Binding var text: String

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search", text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
        .padding(10)
        .background(Color.secondary.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
}

struct ConversationRowView: View {
    let conversation: ConversationSnapshot

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AccountBadge(label: conversation.accountLabel, color: conversation.accountColor)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(conversation.title)
                        .font(.headline)
                        .lineLimit(1)
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
        }
        .padding(.vertical, 4)
    }
}

struct AccountBadge: View {
    let label: String
    let color: AccountBadgeColor

    var body: some View {
        Text(label)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .foregroundStyle(.white)
            .clipShape(Capsule())
    }

    private var backgroundColor: Color {
        switch color {
        case .work: return .blue
        case .personal: return .green
        case .custom: return .purple
        }
    }
}
