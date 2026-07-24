import Foundation

public enum DeepLink: Equatable, Sendable {
    case space(resourceName: String)
}

public enum DeepLinkParser {
    public static func parse(_ url: URL) throws -> DeepLink {
        guard url.scheme == "gchatmulti", url.host == "space" else {
            throw DeepLinkError.unsupported
        }

        let resourceName = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let decoded = resourceName.removingPercentEncoding ?? resourceName
        guard !decoded.isEmpty else {
            throw DeepLinkError.invalidResource
        }

        return .space(resourceName: decoded)
    }
}

public enum DeepLinkError: Error {
    case unsupported
    case invalidResource
}
