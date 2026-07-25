import SwiftUI
import GoogleChatMultiCore

struct InboxView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        List {
            if model.accounts.isEmpty {
                ContentUnavailableCompat(
                    title: "Add a Google account",
                    systemImage: "person.crop.circle.badge.plus",
                    description: "Sign in with personal and work accounts to build one unified inbox."
                )
            } else {
                ForEach(model.visibleConversations) { row in
                    Button {
                        model.open(row)
                    } label: {
                        ConversationRowView(row: row)
                    }
                    .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("GoogleChat Multi")
        .searchable(text: $model.searchQuery, prompt: "Search loaded chats")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    model.path.append(.accounts)
                } label: {
                    Image(systemName: "person.2")
                }
                .accessibilityLabel("Accounts")
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Task { await model.refresh() }
                } label: {
                    if model.isRefreshing {
                        ProgressView()
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .accessibilityLabel("Refresh")
            }
        }
        .safeAreaInset(edge: .top) {
            FilterChipBar(selection: $model.filter, accounts: model.accounts)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color("CanvasBackground").opacity(0.96))
        }
        .background(Color("CanvasBackground").ignoresSafeArea())
        .onAppear {
            Task { await model.refresh() }
        }
        .onChange(of: model.path) { path in
            // Returning to the inbox (home) from a thread/accounts screen.
            if path.isEmpty {
                Task { await model.refresh() }
            }
        }
        .refreshable {
            await model.refresh()
        }
    }
}

struct FilterChipBar: View {
    @Binding var selection: InboxFilter
    let accounts: [LinkedAccount]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip("All", selected: selection == .all) { selection = .all }
                ForEach(accounts) { account in
                    chip(account.label, selected: selection == .accountLabel(account.label)) {
                        selection = .accountLabel(account.label)
                    }
                }
            }
        }
    }

    private func chip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .foregroundStyle(selected ? Color("ChipSelectedText") : Color("ChipText"))
                .background(selected ? Color("ChipSelectedFill") : Color("ChipFill"))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct ConversationRowView: View {
    let row: ConversationSummary

    private var isUnread: Bool { row.unreadCount > 0 }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AccountBadge(label: row.accountLabel, colorHex: row.accountColorHex)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(row.title)
                        .font(.headline.weight(isUnread ? .bold : .semibold))
                        .foregroundStyle(Color("PrimaryText"))
                        .lineLimit(1)
                    Spacer()
                    Text(row.lastActivityAt, style: .relative)
                        .font(isUnread ? .caption.weight(.semibold) : .caption)
                        .foregroundStyle(isUnread ? Color("PrimaryText") : Color("SecondaryText"))
                }
                Text(row.lastMessagePreview)
                    .font(isUnread ? .subheadline.weight(.semibold) : .subheadline)
                    .foregroundStyle(isUnread ? Color("PrimaryText") : Color("SecondaryText"))
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 2)
        .accessibilityValue(isUnread ? "Unread" : "Read")
    }
}

struct AccountBadge: View {
    let label: String
    let colorHex: String

    var body: some View {
        Text(shortLabel)
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white)
            .frame(width: 44, height: 24)
            .background(Color(hex: colorHex) ?? .orange)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .accessibilityLabel(label)
    }

    private var shortLabel: String {
        if label.localizedCaseInsensitiveContains("work") { return "Work" }
        if label.localizedCaseInsensitiveContains("personal")
            || label.localizedCaseInsensitiveContains("home") {
            return "Home"
        }
        return String(label.prefix(4))
    }
}

/// iOS 16-friendly stand-in for ContentUnavailableView.
struct ContentUnavailableCompat: View {
    let title: String
    let systemImage: String
    let description: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 40))
                .foregroundStyle(Color("SecondaryText"))
            Text(title)
                .font(.title3.weight(.semibold))
            Text(description)
                .font(.subheadline)
                .foregroundStyle(Color("SecondaryText"))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }
}

extension Color {
    init?(hex: String) {
        var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("#") { cleaned.removeFirst() }
        guard cleaned.count == 6, let value = Int(cleaned, radix: 16) else { return nil }
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        self = Color(red: r, green: g, blue: b)
    }
}
