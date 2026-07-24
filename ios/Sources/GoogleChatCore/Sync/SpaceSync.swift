import Foundation

public enum SpaceSync {
    /// Maps Chat API spaces into inbox conversations for one account.
    public static func conversations(
        from spaces: [Space],
        account: Account,
        lastActivityAt: Date = Date(),
        previewProvider: (Space) -> String = { _ in "" }
    ) -> [Conversation] {
        spaces.map { space in
            let title: String
            if let display = space.displayName, !display.isEmpty {
                title = display
            } else if space.spaceType == .directMessage {
                title = "DM"
            } else {
                title = space.name
            }
            return Conversation(
                id: ConversationID(accountID: account.id, spaceName: space.name),
                title: title,
                lastMessagePreview: previewProvider(space),
                lastActivityAt: lastActivityAt,
                unread: false,
                accountLabel: account.label,
                badgeColorHex: account.badgeColorHex
            )
        }
    }
}
