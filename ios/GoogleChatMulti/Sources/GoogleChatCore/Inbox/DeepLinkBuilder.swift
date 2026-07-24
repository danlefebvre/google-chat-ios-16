import Foundation

/// URL scheme for ntfy tap actions: gchatmulti://space/{accountId}:{spaceName}
public enum DeepLinkBuilder {
    public static func spaceURL(conversationId: ConversationId) -> URL? {
        var components = URLComponents()
        components.scheme = "gchatmulti"
        components.host = "space"
        components.path = "/\(conversationId.rawValue)"
        return components.url
    }
}
