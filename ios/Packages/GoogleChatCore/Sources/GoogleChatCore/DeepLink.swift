import Foundation

public enum DeepLink: Equatable, Sendable {
    case space(resourceName: String)

    public init(url: URL) throws {
        guard url.scheme == "gchatmulti" else {
            throw DeepLinkError.unsupported
        }

        switch url.host {
        case "space":
            let encoded = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            guard let decoded = encoded.removingPercentEncoding, !decoded.isEmpty else {
                throw DeepLinkError.invalidPath
            }
            self = .space(resourceName: decoded)
        default:
            throw DeepLinkError.unsupported
        }
    }

    public func url(scheme: String = "gchatmulti") -> URL {
        switch self {
        case let .space(resourceName):
            let encoded = resourceName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? resourceName
            return URL(string: "\(scheme)://space/\(encoded)")!
        }
    }
}

public enum DeepLinkError: Error {
    case unsupported
    case invalidPath
}
