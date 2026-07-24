import Foundation

/// Foreground-only fallback when ntfy/relay is down and the Chat app is open.
public struct InAppBanner: Identifiable, Hashable, Sendable {
    public var id: String
    public var accountLabel: String
    public var spaceTitle: String
    public var preview: String
    public var accountId: AccountID
    public var spaceName: String

    public init(
        id: String = UUID().uuidString,
        accountLabel: String,
        spaceTitle: String,
        preview: String,
        accountId: AccountID,
        spaceName: String
    ) {
        self.id = id
        self.accountLabel = accountLabel
        self.spaceTitle = spaceTitle
        self.preview = preview
        self.accountId = accountId
        self.spaceName = spaceName
    }

    public var title: String { "[\(accountLabel)] \(spaceTitle)" }
}

public final class InAppBannerCenter: @unchecked Sendable {
    public private(set) var current: InAppBanner?
    public var onChange: ((InAppBanner?) -> Void)?

    public init() {}

    public func present(_ banner: InAppBanner) {
        current = banner
        onChange?(banner)
    }

    public func dismiss() {
        current = nil
        onChange?(nil)
    }
}
