import Foundation

public enum AppDeepLink: Equatable, Sendable {
    case space(accountId: AccountID, spaceName: String)
}

public enum DeepLinkError: Error, Equatable {
    case unsupportedScheme
    case unsupportedHost
    case missingAccountId
    case invalidAccountId
    case missingSpaceName
}

public enum DeepLinkParser {
    public static let scheme = "googlechatmulti"

    public static func parse(_ url: URL) throws -> AppDeepLink {
        guard url.scheme == scheme else { throw DeepLinkError.unsupportedScheme }
        guard url.host == "space" else { throw DeepLinkError.unsupportedHost }

        let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !path.isEmpty else { throw DeepLinkError.missingSpaceName }
        let spaceName = path.removingPercentEncoding ?? path

        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let accountRaw = components.queryItems?.first(where: { $0.name == "accountId" })?.value
        else {
            throw DeepLinkError.missingAccountId
        }

        guard let accountId = AccountID(rawValue: accountRaw) else {
            throw DeepLinkError.invalidAccountId
        }

        return .space(accountId: accountId, spaceName: spaceName)
    }
}

public enum DeepLinkBuilder {
    public static func spaceURL(accountId: AccountID, spaceName: String) -> URL {
        var components = URLComponents()
        components.scheme = DeepLinkParser.scheme
        components.host = "space"
        components.path = "/" + spaceName
        components.queryItems = [
            URLQueryItem(name: "accountId", value: accountId.rawValue),
        ]
        return components.url!
    }
}
