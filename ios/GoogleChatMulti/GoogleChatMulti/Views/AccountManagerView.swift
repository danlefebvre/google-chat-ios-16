import SwiftUI
import GoogleChatCore

struct AccountManagerView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        List {
            Section("Signed in") {
                if appState.accounts.isEmpty {
                    Text("No accounts yet. Add a Google account to get started.")
                        .foregroundStyle(.secondary)
                }
                ForEach(appState.accounts) { account in
                    HStack {
                        AccountBadge(label: account.displayLabel)
                        VStack(alignment: .leading) {
                            Text(account.displayLabel)
                            Text(account.email)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        let account = appState.accounts[index]
                        Task { await appState.signOut(accountId: account.accountId) }
                    }
                }
            }

            Section {
                Button("Add Google Account") {
                    // GoogleSignIn flow: AppAuth + GTMAppAuth per PLAN.md
                }
            }
        }
        .navigationTitle("Accounts")
    }
}
