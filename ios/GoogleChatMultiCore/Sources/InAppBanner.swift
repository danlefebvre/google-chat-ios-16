import Foundation

/// Foreground-only fallback when ntfy/relay is down and the Chat app is open (from PR #7).
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
