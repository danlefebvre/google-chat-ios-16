import Foundation

/// Minimal OAuth scopes from PLAN.md. Re-consent when this set expands.
public enum OAuthScopes {
    public static let all: [String] = [
        "openid",
        "email",
        "profile",
        "https://www.googleapis.com/auth/chat.spaces.readonly",
        "https://www.googleapis.com/auth/chat.messages",
        "https://www.googleapis.com/auth/chat.users.readstate",
        // Workspace Events scopes used by the relay (requested when registering for push):
        "https://www.googleapis.com/auth/chat.spaces",
        "https://www.googleapis.com/auth/chat.messages.readonly",
    ]

    public static var spaceSeparated: String {
        all.joined(separator: " ")
    }
}
