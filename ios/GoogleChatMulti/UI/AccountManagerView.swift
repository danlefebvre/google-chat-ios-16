import SwiftUI
import GoogleChatMultiCore

struct AccountManagerView: View {
    @EnvironmentObject private var model: AppModel
    @StateObject private var signIn = GoogleSignInCoordinator()

    private let palette = ["#C45C26", "#2F6F4E", "#1F4E79", "#7A3E5C"]

    var body: some View {
        List {
            Section("Signed-in accounts") {
                if model.accounts.isEmpty {
                    Text("No accounts yet.")
                        .foregroundStyle(Color("SecondaryText"))
                }
                ForEach(model.accounts) { account in
                    HStack {
                        AccountBadge(label: account.label, colorHex: account.colorHex)
                        VStack(alignment: .leading) {
                            Text(account.label).font(.headline)
                            Text(account.email)
                                .font(.caption)
                                .foregroundStyle(Color("SecondaryText"))
                            if account.relayRegistrationPending {
                                Text("Relay registration pending — notifications offline")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                            }
                        }
                        Spacer()
                        if account.relayRegistrationPending {
                            Button("Retry relay") {
                                Task { await retryRelayRegistration(account) }
                            }
                            .font(.caption)
                        }
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            Task { await model.removeAccount(account.id) }
                        } label: {
                            Label("Remove", systemImage: "trash")
                        }
                    }
                }
            }

            Section("Add account") {
                Button {
                    signIn.startSignIn { result in
                        switch result {
                        case let .success(payload):
                            let color = palette[model.accounts.count % palette.count]
                            let label = suggestedLabel(for: payload.email, index: model.accounts.count)
                            let account = LinkedAccount(
                                id: payload.accountId,
                                email: payload.email,
                                label: label,
                                colorHex: color,
                                relayRegistrationPending: true
                            )
                            model.addAccount(
                                account,
                                refreshToken: payload.refreshToken,
                                accessToken: payload.accessToken
                            )
                            Task {
                                await registerWithRelay(account, refreshToken: payload.refreshToken)
                            }
                        case let .failure(error):
                            model.banner = error.localizedDescription
                        }
                    }
                } label: {
                    Label("Sign in with Google", systemImage: "g.circle.fill")
                }

                if signIn.isBusy {
                    ProgressView("Waiting for Google…")
                }
            }

            Section("Notes") {
                Text("OAuth uses GoogleSignIn UI + Keychain multi-account storage keyed by issuer/sub. Work accounts may need Workspace admin allowlisting. Relay registration sends your Google refresh token once and stores an opaque relay credential for teardown (admin token stays on the server).")
                    .font(.footnote)
                    .foregroundStyle(Color("SecondaryText"))
            }
        }
        .navigationTitle("Accounts")
        .background(Color("CanvasBackground"))
    }

    private func registerWithRelay(_ account: LinkedAccount, refreshToken: String) async {
        guard let client = RelayAdminClient.shared else {
            AppLog.relay.error("registerWithRelay: RelayAdminClient.shared is nil")
            model.markRelayRegistration(pending: true, for: account.id)
            model.banner = "Account saved locally; relay not configured (notifications unavailable)."
            return
        }
        do {
            let credential = try await client.registerAccount(account: account, refreshToken: refreshToken)
            model.authStore.saveRelayCredential(credential, for: account.id)
            model.markRelayRegistration(pending: false, for: account.id)
            AppLog.relay.info("relay credential saved for \(account.id.rawValue, privacy: .public)")
        } catch {
            AppLog.relay.error(
                "registerWithRelay failed: \(error.localizedDescription, privacy: .public)"
            )
            model.markRelayRegistration(pending: true, for: account.id)
            model.banner = "Relay registration failed: \(error.localizedDescription). Retry from Accounts."
        }
    }

    private func retryRelayRegistration(_ account: LinkedAccount) async {
        AppLog.relay.info("retry relay registration for \(account.id.rawValue, privacy: .public)")
        guard let refresh = model.authStore.refreshToken(for: account.id), !refresh.isEmpty else {
            AppLog.relay.error("retry failed: missing refresh token")
            model.banner = "Missing refresh token for relay registration."
            return
        }
        await registerWithRelay(account, refreshToken: refresh)
    }

    private func suggestedLabel(for email: String, index: Int) -> String {
        if index == 0 { return "Personal" }
        if index == 1 { return "Work" }
        return "Account \(index + 1)"
    }
}
