import SwiftUI
import GoogleChatCore

struct AccountsView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @StateObject private var signIn = GoogleSignInCoordinator()

    var body: some View {
        List {
            Section("Signed in") {
                if model.accounts.isEmpty {
                    Text("No accounts yet. Add personal and work Google accounts.")
                        .foregroundStyle(.secondary)
                }
                ForEach(model.accounts, id: \.account.id.rawValue) { auth in
                    HStack {
                        AccountBadge(label: auth.account.label, colorHex: auth.account.badgeColorHex)
                        VStack(alignment: .leading) {
                            Text(auth.account.displayName)
                            Text(auth.account.email)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            Task { await model.removeAccount(auth.account.id) }
                        } label: {
                            Text("Remove")
                        }
                    }
                }
            }
            Section("Add account") {
                Button("Sign in with Google") {
                    Task {
                        do {
                            let auth = try await signIn.signIn(badgeColorHex: model.nextBadgeColor())
                            try model.upsertAuthorization(auth)
                            await model.syncAll()
                        } catch {
                            model.errorMessage = error.localizedDescription
                        }
                    }
                }
                Text("Uses GoogleSignIn UI + Keychain storage keyed by issuer|sub. Email is display-only.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
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

/// Interactive Google Sign-In bridge.
/// On device, wire GoogleSignIn SDK; this coordinator keeps a testable seam.
@MainActor
final class GoogleSignInCoordinator: ObservableObject {
    enum SignInError: Error, LocalizedError {
        case notConfigured
        case cancelled

        var errorDescription: String? {
            switch self {
            case .notConfigured:
                return "Set GIDClientID in Info.plist and add the GoogleSignIn package in Xcode."
            case .cancelled:
                return "Sign-in cancelled"
            }
        }
    }

    func signIn(badgeColorHex: String) async throws -> StoredAuthorization {
        #if canImport(GoogleSignIn)
        // Real SDK path is enabled once GoogleSignIn is linked in the Xcode project.
        throw SignInError.notConfigured
        #else
        throw SignInError.notConfigured
        #endif
    }

    /// Dev/test helper to inject an authorization without the SDK.
    func makeDevAuthorization(
        subject: String,
        email: String,
        label: String,
        badgeColorHex: String,
        accessToken: String,
        refreshToken: String
    ) -> StoredAuthorization {
        StoredAuthorization(
            account: Account(
                id: AccountID(issuer: "https://accounts.google.com", subject: subject),
                email: email,
                displayName: label,
                label: label,
                badgeColorHex: badgeColorHex
            ),
            refreshToken: refreshToken,
            accessToken: accessToken,
            expiry: Date().addingTimeInterval(3600)
        )
    }
}
