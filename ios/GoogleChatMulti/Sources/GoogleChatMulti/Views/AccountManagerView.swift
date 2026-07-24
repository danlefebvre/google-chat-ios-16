import SwiftUI
import GoogleChatCore

struct AccountManagerView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Signed in") {
                    if appState.accounts.isEmpty {
                        Text("No accounts yet. Add personal and work Google accounts.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(appState.accounts) { account in
                        HStack {
                            AccountBadge(label: account.label)
                            VStack(alignment: .leading) {
                                Text(account.label)
                                Text(account.email)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Remove", role: .destructive) {
                                appState.removeAccount(account.accountId)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }

                Section {
                    Button("Add Google Account") {
                        // OAuth flow: GoogleSignIn + GTMAppAuth (configured in Xcode project)
                        addPlaceholderAccount()
                    }
                }
            }
            .navigationTitle("Accounts")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func addPlaceholderAccount() {
        let index = appState.accounts.count + 1
        let accountId = AccountId(issuer: "https://accounts.google.com", sub: "demo-\(index)")
        appState.addAccount(
            AccountProfile(
                accountId: accountId,
                email: "user\(index)@example.com",
                label: index == 1 ? "Work" : "Personal",
                badgeColorHex: index == 1 ? "#4A90D9" : "#50C878"
            )
        )
        appState.upsertConversations([
            ConversationSummary(
                conversationId: ConversationId(accountId: accountId, spaceName: "spaces/demo"),
                accountLabel: index == 1 ? "Work" : "Personal",
                title: index == 1 ? "#eng-standup" : "Family",
                lastMessagePreview: MessagePreviewFormatter().preview(
                    senderName: "Alice",
                    text: "deploy looks good"
                ),
                lastActivity: Date(),
                unread: true
            ),
        ])
    }
}
