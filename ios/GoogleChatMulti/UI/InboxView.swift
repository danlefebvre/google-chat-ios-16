import SwiftUI
import GoogleChatCore

struct InboxView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        List {
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterChip(title: "All", selected: appModel.selectedAccountFilter == nil) {
                            appModel.selectedAccountFilter = nil
                        }
                        ForEach(appModel.accounts, id: \.accountID) { account in
                            FilterChip(
                                title: account.label,
                                selected: appModel.selectedAccountFilter == account.accountID,
                                color: Color(hex: account.colorHex)
                            ) {
                                appModel.selectedAccountFilter = account.accountID
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12))
            }

            Section {
                ForEach(appModel.visibleConversations) { row in
                    Button {
                        appModel.path.append(.thread(
                            accountID: row.accountID,
                            spaceName: row.spaceName,
                            title: row.title,
                            accountLabel: row.accountLabel
                        ))
                    } label: {
                        ConversationRowView(row: row)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle("Chat")
        .searchable(text: $appModel.searchQuery, prompt: "Search loaded chats")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    appModel.path.append(.accounts)
                } label: {
                    Image(systemName: "person.crop.circle.badge.plus")
                }
                .accessibilityLabel("Accounts")
            }
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    Task { await appModel.refreshAllAccounts() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .accessibilityLabel("Refresh")
            }
        }
    }
}

struct ConversationRowView: View {
    let row: ConversationSummary

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(row.accountLabel)
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.accentColor.opacity(0.15))
                .accessibilityLabel("Account \(row.accountLabel)")
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(row.title)
                        .font(.headline)
                        .lineLimit(1)
                    Spacer()
                    Text(row.lastActivityAt, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(row.lastMessagePreview.isEmpty ? "No recent messages" : row.lastMessagePreview)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            if row.unreadCount > 0 {
                Circle()
                    .frame(width: 8, height: 8)
                    .foregroundStyle(Color.accentColor)
                    .accessibilityLabel("Unread")
            }
        }
        .padding(.vertical, 4)
    }
}

struct FilterChip: View {
    let title: String
    var selected: Bool
    var color: Color = .accentColor
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(selected ? color.opacity(0.2) : Color.secondary.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(selected ? color : .clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)
        let r, g, b: Double
        switch cleaned.count {
        case 6:
            r = Double((int >> 16) & 0xFF) / 255
            g = Double((int >> 8) & 0xFF) / 255
            b = Double(int & 0xFF) / 255
        default:
            r = 0.23; g = 0.51; b = 0.96
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}
