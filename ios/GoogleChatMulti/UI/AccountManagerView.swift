import SwiftUI
import GoogleChatCore

struct AccountManagerView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var draftLabel = ""
    @State private var draftEmail = ""
    @State private var draftIssuer = "https://accounts.google.com"
    @State private var draftSubject = ""
    @State private var draftRefresh = ""
    @State private var info: String?

    var body: some View {
        Form {
            Section("Signed-in accounts") {
                if appModel.accounts.isEmpty {
                    Text("No accounts yet. Add personal + work (N accounts supported).")
                        .foregroundStyle(.secondary)
                }
                ForEach(appModel.accounts, id: \.accountID) { account in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(account.label).font(.headline)
                            Text(account.accountID.email ?? account.accountID.rawValue)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Remove", role: .destructive) {
                            Task { await appModel.removeAccount(account.accountID) }
                        }
                    }
                }
            }

            Section("Add account (dev / Testing OAuth)") {
                TextField("Label (Work / Personal)", text: $draftLabel)
                TextField("Email", text: $draftEmail)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                TextField("Issuer", text: $draftIssuer)
                    .textInputAutocapitalization(.never)
                TextField("Subject (sub)", text: $draftSubject)
                    .textInputAutocapitalization(.never)
                SecureField("Refresh token", text: $draftRefresh)
                Button("Save account + register relay") {
                    Task { await save() }
                }
                .disabled(!canSave)
            }

            if let info {
                Section {
                    Text(info).font(.footnote)
                }
            }

            Section("Notes") {
                Text("Production sign-in uses GoogleSignIn for the interactive flow, then stores N authorizations in Keychain keyed by {issuer, sub}. Wire your OAuth client ID in Config.xcconfig before device testing.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Accounts")
    }

    private var canSave: Bool {
        !draftLabel.isEmpty && !draftSubject.isEmpty && !draftRefresh.isEmpty
    }

    private func save() async {
        let accountID = AccountID(issuer: draftIssuer, subject: draftSubject, email: draftEmail)
        let auth = AccountAuthorization(
            accountID: accountID,
            label: draftLabel,
            refreshToken: draftRefresh,
            accessToken: "",
            accessTokenExpiresAt: .distantPast,
            colorHex: draftLabel.lowercased().contains("work") ? "#D97706" : "#2563EB"
        )
        do {
            try await appModel.authStore.upsert(auth)
            let relay = RelayClient(baseURL: appModel.relayBaseURL)
            try await relay.registerAccount(
                accountID: accountID,
                email: draftEmail,
                label: draftLabel,
                refreshToken: draftRefresh
            )
            appModel.accounts = try await appModel.authStore.all()
            await appModel.refresh(account: auth)
            appModel.conversations = try await appModel.conversationStore.allConversations()
            info = "Saved \(draftLabel). Relay registered."
            draftSubject = ""
            draftRefresh = ""
        } catch {
            info = error.localizedDescription
        }
    }
}
