import Foundation

/// Minimal OAuth scopes for MVP (re-consent when expanding).
public enum OAuthScopes {
    public static let openID = "openid"
    public static let email = "email"
    public static let profile = "profile"
    public static let chatSpacesReadonly = "https://www.googleapis.com/auth/chat.spaces.readonly"
    public static let chatMessages = "https://www.googleapis.com/auth/chat.messages"
    public static let chatUsersReadState = "https://www.googleapis.com/auth/chat.users.readstate"

    public static let mvp: [String] = [
        openID,
        email,
        profile,
        chatSpacesReadonly,
        chatMessages,
        chatUsersReadState,
    ]
}
