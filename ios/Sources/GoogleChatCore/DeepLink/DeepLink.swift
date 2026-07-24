import Foundation

public enum DeepLink: Hashable, Sendable {
    case space(accountID: AccountID, spaceName: String)

    public static let scheme = "googlechatmulti"

    public var url: URL {
        switch self {
        case let .space(accountID, spaceName):
            var components = URLComponents()
            components.scheme = Self.scheme
            components.host = "space"
            components.queryItems = [
                URLQueryItem(name: "account", value: accountID.key),
                URLQueryItem(name: "space", value: spaceName),
            ]
            return components.url!
        }
    }

    public static func parse(_ url: URL) throws -> DeepLink {
        guard url.scheme == scheme else {
            throw DeepLinkError.unsupportedScheme(url.scheme)
        }
        guard url.host == "space" else {
            throw DeepLinkError.unsupportedHost(url.host)
        }
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let account = items.first(where: { $0.name == "account" })?.value
        let space = items.first(where: { $0.name == "space" })?.value
        guard let account, let space, let accountID = try? AccountID(key: account) else {
            throw DeepLinkError.missingParameters
        }
        return .space(accountID: accountID, spaceName: space)
    }
}

public enum DeepLinkError: Error, Equatable {
    case unsupportedScheme(String?)
    case unsupportedHost(String?)
    case missingParameters
}
