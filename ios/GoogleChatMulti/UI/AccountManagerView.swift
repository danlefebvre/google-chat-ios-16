import SwiftUI
import GoogleChatMultiCore

enum AccountColorPalette {
    static let hexValues = [
        "#C45C26",
        "#2F6F4E",
        "#1F4E79",
        "#7A3E5C",
        "#8A6D3B",
        "#3D5A5B",
        "#6B3F69",
        "#4A6741",
    ]

    static func color(at index: Int) -> String {
        hexValues[index % hexValues.count]
    }
}

/// Keep in sync with `MAX_ACCOUNT_LABEL_LENGTH` in `relay/src/accounts.ts`.
enum AccountLabelLimits {
    static let maxLength = 32
}

struct AccountManagerView: View {
    @EnvironmentObject private var model: AppModel
    @StateObject private var signIn = GoogleSignInCoordinator()
    @State private var editingAccount: LinkedAccount?

    var body: some View {
        List {
            Section("Signed-in accounts") {
                if model.accounts.isEmpty {
                    Text("No accounts yet.")
                        .foregroundStyle(Color("SecondaryText"))
                }
                ForEach(model.accounts) { account in
                    HStack(spacing: 12) {
                        Button {
                            editingAccount = account
                        } label: {
                            HStack(spacing: 12) {
                                AccountBadge(label: account.label, colorHex: account.colorHex)
                                VStack(alignment: .leading) {
                                    Text(account.label).font(.headline)
                                        .foregroundStyle(Color("PrimaryText"))
                                    Text(account.email)
                                        .font(.caption)
                                        .foregroundStyle(Color("SecondaryText"))
                                    if account.relayRegistrationPending {
                                        Text("Relay registration pending — notifications offline")
                                            .font(.caption2)
                                            .foregroundStyle(.orange)
                                    }
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color("SecondaryText"))
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Edits label and color")

                        if account.relayRegistrationPending {
                            Button("Retry relay") {
                                Task { await retryRelayRegistration(account) }
                            }
                            .font(.caption)
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
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
                            let color = AccountColorPalette.color(at: model.accounts.count)
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
                Text("Tap an account to rename it or change its badge color. OAuth uses GoogleSignIn UI + Keychain multi-account storage keyed by issuer/sub. Work accounts may need Workspace admin allowlisting. Relay registration sends your Google refresh token once and stores an opaque relay credential for teardown (admin token stays on the server).")
                    .font(.footnote)
                    .foregroundStyle(Color("SecondaryText"))
            }
        }
        .navigationTitle("Accounts")
        .background(Color("CanvasBackground"))
        .sheet(item: $editingAccount) { account in
            EditAccountSheet(account: account) { label, colorHex in
                Task {
                    await model.updateAccountDisplay(
                        account.id,
                        label: label,
                        colorHex: colorHex
                    )
                }
            }
        }
    }

    private func registerWithRelay(_ account: LinkedAccount, refreshToken: String) async {
        guard let client = RelayAdminClient.shared else {
            AppLog.relay.error("registerWithRelay: RelayAdminClient.shared is nil")
            model.markRelayRegistration(pending: true, for: account.id)
            model.banner = "Account saved locally; relay not configured (notifications unavailable)."
            return
        }
        do {
            // Prefer the latest label from the store in case the user edited before retry.
            let labeled = model.accounts.first(where: { $0.id == account.id }) ?? account
            let credential = try await client.registerAccount(account: labeled, refreshToken: refreshToken)
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

struct EditAccountSheet: View {
    let account: LinkedAccount
    var onSave: (String, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var label: String
    @State private var colorHex: String

    init(account: LinkedAccount, onSave: @escaping (String, String) -> Void) {
        self.account = account
        self.onSave = onSave
        _label = State(initialValue: account.label)
        _colorHex = State(initialValue: account.colorHex)
    }

    private var trimmedLabel: String {
        label.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !trimmedLabel.isEmpty
            && trimmedLabel.count <= AccountLabelLimits.maxLength
            && (trimmedLabel != account.label || colorHex != account.colorHex)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Account label", text: $label)
                        .textInputAutocapitalization(.words)
                        .disableAutocorrection(true)
                        .accessibilityLabel("Account label")
                        .onChange(of: label) { newValue in
                            if newValue.count > AccountLabelLimits.maxLength {
                                label = String(newValue.prefix(AccountLabelLimits.maxLength))
                            }
                        }
                } header: {
                    Text("Label")
                } footer: {
                    Text("\(trimmedLabel.count)/\(AccountLabelLimits.maxLength)")
                        .foregroundStyle(
                            trimmedLabel.count >= AccountLabelLimits.maxLength
                                ? Color.orange
                                : Color("SecondaryText")
                        )
                }

                Section("Badge color") {
                    let columns = [GridItem(.adaptive(minimum: 40), spacing: 12)]
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(swatchColors, id: \.self) { hex in
                            Button {
                                colorHex = hex
                            } label: {
                                Circle()
                                    .fill(Color(hex: hex) ?? .gray)
                                    .frame(width: 36, height: 36)
                                    .overlay {
                                        if colorHex.caseInsensitiveCompare(hex) == .orderedSame {
                                            Image(systemName: "checkmark")
                                                .font(.caption.weight(.bold))
                                                .foregroundStyle(.white)
                                        }
                                    }
                                    .accessibilityLabel("Color \(hex)")
                                    .accessibilityAddTraits(
                                        colorHex.caseInsensitiveCompare(hex) == .orderedSame
                                            ? .isSelected
                                            : []
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Preview") {
                    HStack(spacing: 12) {
                        AccountBadge(
                            label: trimmedLabel.isEmpty ? "…" : trimmedLabel,
                            colorHex: colorHex
                        )
                        VStack(alignment: .leading, spacing: 2) {
                            Text(trimmedLabel.isEmpty ? "Label required" : trimmedLabel)
                                .font(.headline)
                            Text(account.email)
                                .font(.caption)
                                .foregroundStyle(Color("SecondaryText"))
                        }
                    }
                }
            }
            .navigationTitle("Edit Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(trimmedLabel, colorHex)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    /// Palette plus the account's current color if it is a custom leftover.
    private var swatchColors: [String] {
        var colors = AccountColorPalette.hexValues
        if !colors.contains(where: { $0.caseInsensitiveCompare(account.colorHex) == .orderedSame }) {
            colors.insert(account.colorHex, at: 0)
        }
        return colors
    }
}
