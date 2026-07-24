import Foundation

public enum OAuthScopes {
    public static let all: [String] = [
        "openid",
        "email",
        "profile",
        "https://www.googleapis.com/auth/chat.spaces.readonly",
        "https://www.googleapis.com/auth/chat.messages",
        "https://www.googleapis.com/auth/chat.users.readstate",
    ]

    public static var spaceSeparated: String { all.joined(separator: " ") }
}
