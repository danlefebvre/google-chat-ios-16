import Foundation

public extension JSONDecoder {
    static let chat: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            if let date = RFC3339Date.parse(raw) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid RFC3339 date: \(raw)"
            )
        }
        return decoder
    }()
}

public extension JSONEncoder {
    static let chat: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
}

enum RFC3339Date {
    private static let fractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let wholeSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static func parse(_ raw: String) -> Date? {
        fractional.date(from: raw) ?? wholeSeconds.date(from: raw)
    }
}

public struct SpaceListResponse: Codable, Sendable {
    public var spaces: [ChatSpace]
    public var nextPageToken: String?

    public init(spaces: [ChatSpace], nextPageToken: String? = nil) {
        self.spaces = spaces
        self.nextPageToken = nextPageToken
    }
}

public struct ChatSpace: Codable, Hashable, Sendable {
    public var name: String
    public var displayName: String?
    public var spaceType: String?
    public var lastActiveTime: Date?

    public init(
        name: String,
        displayName: String? = nil,
        spaceType: String? = nil,
        lastActiveTime: Date? = nil
    ) {
        self.name = name
        self.displayName = displayName
        self.spaceType = spaceType
        self.lastActiveTime = lastActiveTime
    }

    public var isDirectMessage: Bool {
        spaceType == "DIRECT_MESSAGE"
    }

    public var resolvedTitle: String {
        let trimmed = displayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmed.isEmpty { return trimmed }
        return isDirectMessage ? "DM" : name
    }
}

public struct MessageListResponse: Codable, Sendable {
    public var messages: [ChatMessage]
    public var nextPageToken: String?

    public init(messages: [ChatMessage], nextPageToken: String? = nil) {
        self.messages = messages
        self.nextPageToken = nextPageToken
    }
}

public struct ChatMessage: Codable, Hashable, Identifiable, Sendable {
    public var name: String
    public var text: String?
    public var createTime: Date?
    public var sender: ChatSender?
    public var attachment: [ChatAttachment]?
    public var emojiReactionSummaries: [EmojiReactionSummary]?

    public var id: String { name }

    public init(
        name: String,
        text: String? = nil,
        createTime: Date? = nil,
        sender: ChatSender? = nil,
        attachment: [ChatAttachment]? = nil,
        emojiReactionSummaries: [EmojiReactionSummary]? = nil
    ) {
        self.name = name
        self.text = text
        self.createTime = createTime
        self.sender = sender
        self.attachment = attachment
        self.emojiReactionSummaries = emojiReactionSummaries
    }
}

public struct ChatSender: Codable, Hashable, Sendable {
    public var name: String?
    public var displayName: String?
    public var type: String?

    public init(name: String? = nil, displayName: String? = nil, type: String? = nil) {
        self.name = name
        self.displayName = displayName
        self.type = type
    }

    /// Prefer API displayName; never surface raw `users/…` ids in the UI.
    public var resolvedDisplayName: String {
        let trimmed = displayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmed.isEmpty { return trimmed }
        return "Someone"
    }

    /// True when `displayName` looks like a bare numeric user id (not a real name).
    public var hasHumanReadableName: Bool {
        let trimmed = displayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else { return false }
        if trimmed.allSatisfy(\.isNumber) { return false }
        if trimmed.hasPrefix("users/") { return false }
        return true
    }
}

public struct MembershipListResponse: Codable, Sendable {
    public var memberships: [ChatMembership]
    public var nextPageToken: String?

    public init(memberships: [ChatMembership], nextPageToken: String? = nil) {
        self.memberships = memberships
        self.nextPageToken = nextPageToken
    }
}

public struct ChatMembership: Codable, Hashable, Sendable {
    public var name: String?
    public var state: String?
    public var member: ChatSender?

    public init(name: String? = nil, state: String? = nil, member: ChatSender? = nil) {
        self.name = name
        self.state = state
        self.member = member
    }
}

public struct ChatAttachment: Codable, Hashable, Sendable {
    public var name: String?
    public var contentName: String?
    public var contentType: String?
    public var downloadUri: String?
    public var thumbnailUri: String?
    public var source: String?
    public var attachmentDataRef: AttachmentDataRef?

    public init(
        name: String? = nil,
        contentName: String? = nil,
        contentType: String? = nil,
        downloadUri: String? = nil,
        thumbnailUri: String? = nil,
        source: String? = nil,
        attachmentDataRef: AttachmentDataRef? = nil
    ) {
        self.name = name
        self.contentName = contentName
        self.contentType = contentType
        self.downloadUri = downloadUri
        self.thumbnailUri = thumbnailUri
        self.source = source
        self.attachmentDataRef = attachmentDataRef
    }

    public var isImage: Bool {
        let type = (contentType ?? "").lowercased()
        if type.hasPrefix("image/") { return true }
        let file = (contentName ?? "").lowercased()
        return [".png", ".jpg", ".jpeg", ".gif", ".webp", ".heic"].contains { file.hasSuffix($0) }
    }

    /// Resource name for `media.download` (uploaded Chat files, not Drive).
    public var mediaResourceName: String? {
        let raw = attachmentDataRef?.resourceName?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (raw?.isEmpty == false) ? raw : nil
    }
}

/// Response from Chat media upload — use `attachmentUploadToken` when creating a message.
public struct AttachmentUploadResponse: Codable, Hashable, Sendable {
    public var attachmentDataRef: AttachmentDataRef?

    public init(attachmentDataRef: AttachmentDataRef? = nil) {
        self.attachmentDataRef = attachmentDataRef
    }

    public var attachmentUploadToken: String? {
        attachmentDataRef?.attachmentUploadToken
    }
}

public struct AttachmentDataRef: Codable, Hashable, Sendable {
    public var resourceName: String?
    public var attachmentUploadToken: String?

    public init(resourceName: String? = nil, attachmentUploadToken: String? = nil) {
        self.resourceName = resourceName
        self.attachmentUploadToken = attachmentUploadToken
    }
}

public struct EmojiReactionSummary: Codable, Hashable, Sendable {
    public var emoji: ChatEmoji?
    public var reactionCount: Int?

    public init(emoji: ChatEmoji? = nil, reactionCount: Int? = nil) {
        self.emoji = emoji
        self.reactionCount = reactionCount
    }
}

public struct ChatEmoji: Codable, Hashable, Sendable {
    public var unicode: String?

    public init(unicode: String? = nil) {
        self.unicode = unicode
    }
}

public struct CreateMessageRequest: Codable, Sendable {
    public var text: String
    public var attachment: [CreateMessageAttachment]?

    public init(text: String, attachment: [CreateMessageAttachment]? = nil) {
        self.text = text
        self.attachment = attachment
    }
}

public struct CreateMessageAttachment: Codable, Sendable {
    public var attachmentDataRef: AttachmentDataRef

    public init(uploadToken: String) {
        self.attachmentDataRef = AttachmentDataRef(attachmentUploadToken: uploadToken)
    }
}

public struct CreateReactionRequest: Codable, Sendable {
    public var emoji: ChatEmoji

    public init(unicode: String) {
        self.emoji = ChatEmoji(unicode: unicode)
    }
}
