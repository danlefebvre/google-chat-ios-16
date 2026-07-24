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
                        }
                        Spacer()
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
                                colorHex: color
                            )
                            model.addAccount(
                                account,
                                refreshToken: payload.refreshToken,
                                accessToken: payload.accessToken
                            )
                            Task {
                                try? await RelayAdminClient.shared?.registerAccount(
                                    account: account,
                                    refreshToken: payload.refreshToken
                                )
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
                Text("OAuth uses GoogleSignIn UI + Keychain multi-account storage keyed by issuer/sub. Work accounts may need Workspace admin allowlisting.")
                    .font(.footnote)
                    .foregroundStyle(Color("SecondaryText"))
            }
        }
        .navigationTitle("Accounts")
        .background(Color("CanvasBackground"))
    }

    private func suggestedLabel(for email: String, index: Int) -> String {
        if email.contains(".com") && index == 0 { return "Personal" }
        if index == 1 { return "Work" }
        return "Account \(index + 1)"
    }
}
