import Foundation

/// URL scheme for ntfy tap actions: gchatmulti://space/{accountId}:{spaceName}
public enum DeepLinkBuilder {
    public static func spaceURL(conversationId: ConversationId) -> URL? {
        // Encode ":" and "/" so issuer URLs and `spaces/{id}` stay one path segment.
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~|")
        let encoded = conversationId.rawValue.addingPercentEncoding(withAllowedCharacters: allowed)
            ?? conversationId.rawValue
        return URL(string: "gchatmulti://space/\(encoded)")
    }
}
