import SwiftUI
import GoogleChatCore

struct HomeView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                filterBar
                List(model.filteredConversations) { row in
                    NavigationLink(value: row) {
                        ConversationRowView(row: row)
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Chats")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink("Accounts") {
                        AccountManagerView()
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Refresh") {
                        Task { await model.refresh() }
                    }
                }
            }
            .searchable(text: $model.searchQuery)
            .navigationDestination(for: ConversationRow.self) { row in
                ThreadView(conversation: row)
            }
            .task {
                await model.refresh()
            }
            .alert("Error", isPresented: Binding(
                get: { model.errorMessage != nil },
                set: { if !$0 { model.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(model.errorMessage ?? "")
            }
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                FilterChip(title: "All", isSelected: model.filterLabel == nil) {
                    model.filterLabel = nil
                }
                ForEach(["Work", "Personal"], id: \.self) { label in
                    FilterChip(title: label, isSelected: model.filterLabel == label) {
                        model.filterLabel = label
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
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
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor.opacity(0.2) : Color.gray.opacity(0.15))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct ConversationRowView: View {
    let row: ConversationRow

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AccountBadge(label: row.accountLabel, color: row.accountColor)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(row.title)
                        .font(.headline)
                    Spacer()
                    Text(row.lastActivityAt, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(row.preview)
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
    let color: AccountColor

    var body: some View {
        Text(label.prefix(1))
            .font(.caption.bold())
            .frame(width: 28, height: 28)
            .background(backgroundColor)
            .foregroundStyle(.white)
            .clipShape(Circle())
            .accessibilityLabel(label)
    }

    private var backgroundColor: Color {
        switch color {
        case .work: return .blue
        case .personal: return .green
        case .other: return .orange
        }
    }
}
