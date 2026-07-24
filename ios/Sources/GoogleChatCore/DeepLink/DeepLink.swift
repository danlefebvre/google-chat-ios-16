import Foundation

public enum DeepLink: Equatable, Sendable {
    case openSpace(accountID: AccountID, spaceName: String)

    public init(url: URL) throws {
        guard url.scheme == "googlechatmulti" else {
            throw DeepLinkError.unsupported(url)
        }
        guard url.host == "open" else {
            throw DeepLinkError.unsupported(url)
        }
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let accountRaw = items.first(where: { $0.name == "accountId" })?.value
        let space = items.first(where: { $0.name == "space" })?.value
        guard let accountRaw, let space, !space.isEmpty else {
            throw DeepLinkError.missingParameters
        }
        let accountID = try AccountID(rawValue: accountRaw)
        self = .openSpace(accountID: accountID, spaceName: space)
    }

    public static func openSpaceURL(accountID: AccountID, spaceName: String) -> URL {
        var components = URLComponents()
        components.scheme = "googlechatmulti"
        components.host = "open"
        components.queryItems = [
            URLQueryItem(name: "accountId", value: accountID.rawValue),
            URLQueryItem(name: "space", value: spaceName),
        ]
        return components.url!
    }
}

public enum DeepLinkError: Error, Equatable {
    case unsupported(URL)
    case missingParameters
}
