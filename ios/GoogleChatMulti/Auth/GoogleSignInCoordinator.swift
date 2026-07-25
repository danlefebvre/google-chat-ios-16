import Foundation
import GoogleChatMultiCore

#if canImport(GoogleSignIn)
import GoogleSignIn
import UIKit
#endif

struct GoogleAuthPayload: Sendable {
    let accountId: AccountID
    let email: String
    let accessToken: String
    let refreshToken: String
}

enum GoogleSignInError: LocalizedError {
    case notConfigured
    case missingTokens
    case cancelled

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Google OAuth client ID is not configured. Set GOOGLE_CLIENT_ID in Info.plist."
        case .missingTokens:
            return "Google did not return usable tokens."
        case .cancelled:
            return "Sign-in cancelled."
        }
    }
}

/// Wraps GoogleSignIn interactive flow. On simulator/Linux builds without the SDK,
/// exposes a DEBUG stub for UI wiring.
@MainActor
final class GoogleSignInCoordinator: ObservableObject {
    @Published var isBusy = false

    func startSignIn(completion: @escaping (Result<GoogleAuthPayload, Error>) -> Void) {
        isBusy = true
        let finish: (Result<GoogleAuthPayload, Error>) -> Void = { [weak self] result in
            self?.isBusy = false
            completion(result)
        }

        #if canImport(GoogleSignIn)
        guard let clientID = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String,
              !clientID.isEmpty
        else {
            finish(.failure(GoogleSignInError.notConfigured))
            return
        }

        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        guard let root = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController
        else {
            finish(.failure(GoogleSignInError.notConfigured))
            return
        }

        // Chat client scopes + Workspace Events–capable scopes so the same
        // refresh token can register relay subscriptions (from PR #8 mix-in).
        let scopes = [
            "openid",
            "email",
            "profile",
            "https://www.googleapis.com/auth/chat.spaces.readonly",
            "https://www.googleapis.com/auth/chat.spaces",
            "https://www.googleapis.com/auth/chat.messages",
            "https://www.googleapis.com/auth/chat.messages.readonly",
            "https://www.googleapis.com/auth/chat.memberships.readonly",
            "https://www.googleapis.com/auth/chat.users.readstate",
            // Resolve Chat `users/{id}` → human names (Chat API omits displayName under user auth).
            "https://www.googleapis.com/auth/directory.readonly",
            "https://www.googleapis.com/auth/contacts.other.readonly",
        ]

        GIDSignIn.sharedInstance.signIn(withPresenting: root, hint: nil, additionalScopes: scopes) { result, error in
            if let error {
                finish(.failure(error))
                return
            }
            guard let user = result?.user,
                  let profile = user.profile,
                  let idToken = user.idToken?.tokenString
            else {
                finish(.failure(GoogleSignInError.missingTokens))
                return
            }

            // Prefer subject from ID token payload; fall back to userID.
            let subject = Self.subject(from: idToken) ?? user.userID ?? UUID().uuidString
            let accountId = AccountID(issuer: "https://accounts.google.com", subject: subject)
            let access = user.accessToken.tokenString
            let refresh = user.refreshToken.tokenString
            guard !access.isEmpty else {
                finish(.failure(GoogleSignInError.missingTokens))
                return
            }
            finish(
                .success(
                    GoogleAuthPayload(
                        accountId: accountId,
                        email: profile.email,
                        accessToken: access,
                        refreshToken: refresh
                    )
                )
            )
        }
        #else
        #if DEBUG
        // Deterministic stub so UI/account manager can be exercised without the SDK.
        let index = Int.random(in: 1...999)
        let accountId = AccountID(issuer: "https://accounts.google.com", subject: "stub-\(index)")
        finish(
            .success(
                GoogleAuthPayload(
                    accountId: accountId,
                    email: "user\(index)@example.com",
                    accessToken: "stub-access-\(index)",
                    refreshToken: "stub-refresh-\(index)"
                )
            )
        )
        #else
        finish(.failure(GoogleSignInError.notConfigured))
        #endif
        #endif
    }

    private static func subject(from idToken: String) -> String? {
        let parts = idToken.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        var payload = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while payload.count % 4 != 0 { payload.append("=") }
        guard let data = Data(base64Encoded: payload),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let sub = json["sub"] as? String
        else {
            return nil
        }
        return sub
    }
}
