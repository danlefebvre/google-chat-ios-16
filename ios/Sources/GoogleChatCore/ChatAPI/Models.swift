import Foundation

public struct ChatSpace: Sendable, Equatable, Codable {
    public var name: String
    public var displayName: String
    public var spaceType: String

    public init(name: String, displayName: String, spaceType: String) {
        self.name = name
        self.displayName = displayName
        self.spaceType = spaceType
    }

    public var isDirectMessage: Bool {
        spaceType.uppercased().contains("DIRECT")
    }

    public var resolvedTitle: String {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        return isDirectMessage ? "DM" : name
    }
}

public struct SpacesPage: Sendable, Equatable {
    public var spaces: [ChatSpace]
    public var nextPageToken: String?
}

public struct ChatMessage: Sendable, Equatable, Identifiable {
    public var name: String
    public var spaceName: String
    public var accountID: AccountID
    public var text: String
    public var senderDisplayName: String
    public var createTime: Date
    public var attachmentResourceNames: [String]

    public init(
        name: String,
        spaceName: String,
        accountID: AccountID,
        text: String,
        senderDisplayName: String,
        createTime: Date,
        attachmentResourceNames: [String]
    ) {
        self.name = name
        self.spaceName = spaceName
        self.accountID = accountID
        self.text = text
        self.senderDisplayName = senderDisplayName
        self.createTime = createTime
        self.attachmentResourceNames = attachmentResourceNames
    }

    public var id: String { name }
}

public struct MessagesPage: Sendable, Equatable {
    public var messages: [ChatMessage]
    public var nextPageToken: String?
}
