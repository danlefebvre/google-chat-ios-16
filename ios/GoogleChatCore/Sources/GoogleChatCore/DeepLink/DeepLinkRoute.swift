import Foundation

public enum DeepLinkRoute: Equatable {
    case space(accountId: AccountId, spaceName: String)

    /// `googlechatmulti://space/{accountId}/{spaceName}`
    public static func parse(url: URL) -> DeepLinkRoute? {
        guard url.scheme == "googlechatmulti",
              url.host == "space",
              url.pathComponents.count >= 3
        else {
            return nil
        }
        let accountRaw = url.pathComponents[1]
        let spaceName = url.pathComponents[2...].joined(separator: "/")
        guard let accountId = AccountId.parse(accountRaw.removingPercentEncoding ?? accountRaw) else {
            return nil
        }
        let decodedSpace = spaceName.removingPercentEncoding ?? spaceName
        return .space(accountId: accountId, spaceName: decodedSpace)
    }

    public var url: URL? {
        switch self {
        case .space(let accountId, let spaceName):
            var components = URLComponents()
            components.scheme = "googlechatmulti"
            components.host = "space"
            let encodedAccount = accountId.rawValue.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? accountId.rawValue
            let encodedSpace = spaceName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? spaceName
            components.path = "/\(encodedAccount)/\(encodedSpace)"
            return components.url
        }
    }
}
