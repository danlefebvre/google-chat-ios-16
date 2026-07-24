import Foundation

public enum DeepLink: Hashable, Sendable {
    case space(accountId: AccountID, spaceName: String)
}

public enum DeepLinkError: Error, Equatable {
    case unsupportedScheme
    case malformed
}

public enum DeepLinkParser {
    public static let scheme = "googlechatmulti"

    public static func parse(_ url: URL) throws -> DeepLink {
        guard url.scheme == scheme else { throw DeepLinkError.unsupportedScheme }

        // Parse absoluteString before Foundation decodes `%2F` into path separators.
        // Format: googlechatmulti://spaces/{urlencoded accountId}/{urlencoded spaceName}
        let absolute = url.absoluteString
        let prefix = "\(scheme)://spaces/"
        guard absolute.hasPrefix(prefix) else { throw DeepLinkError.malformed }
        let rest = String(absolute.dropFirst(prefix.count))
        let parts = rest.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2 else { throw DeepLinkError.malformed }

        let accountRaw = String(parts[0]).removingPercentEncoding ?? String(parts[0])
        let spaceRaw = String(parts[1]).removingPercentEncoding ?? String(parts[1])
        let accountId = try AccountID(rawValue: accountRaw)
        guard !spaceRaw.isEmpty else { throw DeepLinkError.malformed }
        return .space(accountId: accountId, spaceName: spaceRaw)
    }

    public static func makeSpaceURL(accountId: AccountID, spaceName: String) -> URL {
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "/")
        let acct = accountId.rawValue.addingPercentEncoding(withAllowedCharacters: allowed) ?? accountId.rawValue
        let space = spaceName.addingPercentEncoding(withAllowedCharacters: allowed) ?? spaceName
        return URL(string: "\(scheme)://spaces/\(acct)/\(space)")!
    }
}
