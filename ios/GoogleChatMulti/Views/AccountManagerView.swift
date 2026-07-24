import SwiftUI
import GoogleChatCore

struct AccountManagerView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        List {
            Section("Signed in") {
                ForEach(model.accounts, id: \.id) { account in
                    HStack {
                        AccountBadge(label: account.label, color: account.color)
                        VStack(alignment: .leading) {
                            Text(account.label)
                            if let email = account.key.email {
                                Text(email)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Button("Remove", role: .destructive) {
                            Task { await model.removeAccount(account) }
                        }
                    }
                }
            }

            Section("Add account") {
                Button("Add Work (demo)") {
                    model.addDemoAccount(label: "Work", color: .work)
                }
                Button("Add Personal (demo)") {
                    model.addDemoAccount(label: "Personal", color: .personal)
                }
                Text("Replace demo buttons with Google Sign-In (AppAuth + GTMAppAuth) using OAuthScopes.required.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Accounts")
    }
}
