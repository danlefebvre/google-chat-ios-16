import SwiftUI
import GoogleChatCore

struct AccountManagerView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var label = ""
    @State private var email = ""

    var body: some View {
        List {
            Section("Signed in") {
                ForEach(appModel.accounts) { account in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(account.label).font(.headline)
                            Text(account.email).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Remove", role: .destructive) {
                            // Relay teardown must run before device wipe (client calls relay DELETE first).
                            Task { await appModel.removeAccount(account.id) }
                        }
                    }
                }
            }

            Section("Add account (dev)") {
                TextField("Label", text: $label)
                TextField("Email", text: $email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                Button("Add") {
                    let subject = UUID().uuidString
                    let account = Account(
                        id: AccountID(issuer: "https://accounts.google.com", subject: subject),
                        email: email,
                        label: label.isEmpty ? email : label,
                        badgeColorHex: appModel.accounts.count.isMultiple(of: 2) ? "#3366FF" : "#2E8B57"
                    )
                    appModel.addAccount(account)
                    label = ""
                    email = ""
                }
                .disabled(email.isEmpty)
            }

            Section("Notes") {
                Text("Production sign-in uses GoogleSignIn + GTMAppAuth, with tokens in Keychain keyed by {issuer, sub}.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Accounts")
    }
}
