import SwiftUI
import GoogleChatCore

struct HomeView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showAccounts = false

    var body: some View {
        VStack(spacing: 0) {
            filterBar
            SearchField(text: $model.searchQuery)
                .padding(.horizontal)
                .padding(.bottom, 8)
            List(model.visibleConversations) { row in
                NavigationLink {
                    ThreadView(conversation: row)
                } label: {
                    ConversationRowView(conversation: row)
                }
            }
            .listStyle(.plain)
            .refreshable { await model.syncAll() }
        }
        .navigationTitle("Chat")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    showAccounts = true
                } label: {
                    Image(systemName: "person.2")
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                if model.isSyncing {
                    ProgressView()
                } else {
                    Button {
                        Task { await model.syncAll() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
        .sheet(isPresented: $showAccounts) {
            NavigationStack {
                AccountsView()
            }
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(title: "All", selected: isAll) {
                    model.filter = .all
                }
                ForEach(uniqueLabels, id: \.self) { label in
                    FilterChip(title: label, selected: isSelected(label)) {
                        model.filter = .accountLabel(label)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    private var uniqueLabels: [String] {
        Array(Set(model.accounts.map(\.account.label))).sorted()
    }

    private var isAll: Bool {
        if case .all = model.filter { return true }
        return false
    }

    private func isSelected(_ label: String) -> Bool {
        if case .accountLabel(let value) = model.filter { return value == label }
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
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(selected ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.12))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct SearchField: View {
    @Binding var text: String

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search", text: $text)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
        }
        .padding(10)
        .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
    }
}

struct ConversationRowView: View {
    let conversation: ConversationSummary

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            AccountBadge(label: conversation.accountLabel, colorHex: conversation.badgeColorHex)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(conversation.title)
                        .font(.headline)
                        .lineLimit(1)
                    Spacer()
                    Text(conversation.lastActivityAt, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(conversation.lastMessagePreview)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            if conversation.unreadCount > 0 {
                Text("\(conversation.unreadCount)")
                    .font(.caption2.weight(.bold))
                    .padding(6)
                    .background(Color.accentColor, in: Circle())
                    .foregroundStyle(.white)
            }
        }
        .padding(.vertical, 4)
    }
}

struct AccountBadge: View {
    let label: String
    let colorHex: String

    var body: some View {
        Text(label)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(hex: colorHex).opacity(0.18), in: Capsule())
            .foregroundStyle(Color(hex: colorHex))
    }
}

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)
        let r, g, b: UInt64
        switch cleaned.count {
        case 6:
            (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (0x88, 0x88, 0x88)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: 1
        )
    }
}
