import SwiftUI
import GoogleChatCore

struct AccountManagerView: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var showingAddSheet = false

    var body: some View {
        List {
            Section("Signed in") {
                if appModel.accounts.isEmpty {
                    Text("No accounts yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(appModel.accounts, id: \.accountId.rawValue) { account in
                        HStack {
                            AccountBadge(label: account.label, color: account.color)
                            VStack(alignment: .leading) {
                                Text(account.label)
                                if let email = account.accountId.displayEmail {
                                    Text(email)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .onDelete(perform: removeAccounts)
                }
            }

            Section {
                Button("Add Google account") {
                    showingAddSheet = true
                }
            }
        }
        .navigationTitle("Accounts")
        .sheet(isPresented: $showingAddSheet) {
            AddAccountSheet()
        }
    }

    private func removeAccounts(at offsets: IndexSet) {
        Task {
            for index in offsets {
                let account = appModel.accounts[index]
                try? await appModel.removeAccount(account)
            }
        }
    }
}

private struct AddAccountSheet: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var label = "Work"
    @State private var color: AccountBadgeColor = .work
    @State private var accessToken = ""
    @State private var refreshToken = ""
    @State private var idToken = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Account") {
                    TextField("Label", text: $label)
                    Picker("Badge", selection: $color) {
                        Text("Work").tag(AccountBadgeColor.work)
                        Text("Personal").tag(AccountBadgeColor.personal)
                    }
                }

                Section("OAuth tokens") {
                    Text("Complete Google OAuth in a browser, then paste tokens here for MVP bootstrap. Replace with GoogleSignIn + AppAuth UI flow before device testing.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    SecureField("Access token", text: $accessToken)
                    SecureField("Refresh token", text: $refreshToken)
                    SecureField("ID token", text: $idToken)
                }
            }
            .navigationTitle("Add account")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(accessToken.isEmpty || idToken.isEmpty)
                }
            }
        }
    }

    private func save() {
        do {
            let token = OAuthTokenResponse(
                accessToken: accessToken,
                refreshToken: refreshToken.isEmpty ? nil : refreshToken,
                expiresIn: 3600,
                idToken: idToken
            )
            let account = try OAuthService.storedAccount(from: token, label: label, color: color)
            try appModel.addAccount(account)
            dismiss()
            Task { await appModel.refresh() }
        } catch {
            appModel.errorMessage = error.localizedDescription
        }
    }
}
