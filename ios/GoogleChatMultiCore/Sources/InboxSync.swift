import Foundation

public protocol ConversationCaching: AnyObject, Sendable {
    /// Replace the authoritative snapshot for a refresh (stale rows must not linger).
    func replaceConversations(_ rows: [ConversationSummary]) async throws
    func loadConversations() async throws -> [ConversationSummary]
    func deleteConversations(accountId: AccountID) async throws
}

public enum InboxSyncError: Error, Equatable, Sendable {
    case spacePaginationLimitExceeded
}

public actor InboxSyncService {
    private let api: ChatAPIClient
    private let people: PeopleClient?
    private let cache: any ConversationCaching
    private let previewConcurrencyLimit: Int
    private let maxSpacePages: Int

    public init(
        api: ChatAPIClient,
        cache: any ConversationCaching,
        people: PeopleClient? = nil,
        previewConcurrencyLimit: Int = 4,
        maxSpacePages: Int = 100
    ) {
        self.api = api
        self.people = people
        self.cache = cache
        self.previewConcurrencyLimit = max(1, previewConcurrencyLimit)
        self.maxSpacePages = max(1, maxSpacePages)
    }

    public func refreshAccounts(_ accounts: [LinkedAccount]) async throws -> [ConversationSummary] {
        var merged: [ConversationSummary] = []

        for account in accounts {
            let spaces = try await listAllSpaces(accountId: account.id)
            let summaries = try await fetchSummaries(account: account, spaces: spaces)
            merged.append(contentsOf: summaries)
        }

        let sorted = InboxMerger.merge(merged)
        try await cache.replaceConversations(sorted)
        return sorted
    }

    public func cachedInbox() async throws -> [ConversationSummary] {
        InboxMerger.merge(try await cache.loadConversations())
    }

    public func purgeAccount(_ accountId: AccountID) async throws {
        try await cache.deleteConversations(accountId: accountId)
    }

    private func fetchSummaries(
        account: LinkedAccount,
        spaces: [ChatSpace]
    ) async throws -> [ConversationSummary] {
        if spaces.isEmpty { return [] }

        return try await withThrowingTaskGroup(of: (Int, ConversationSummary).self) { group in
            var results: [(Int, ConversationSummary)] = []
            results.reserveCapacity(spaces.count)

            var nextIndex = 0
            let limit = min(previewConcurrencyLimit, spaces.count)

            func addTask(at index: Int) {
                let space = spaces[index]
                group.addTask {
                    let summary = await self.makeSummary(account: account, space: space)
                    return (index, summary)
                }
            }

            while nextIndex < limit {
                addTask(at: nextIndex)
                nextIndex += 1
            }

            while let (index, summary) = try await group.next() {
                results.append((index, summary))
                if nextIndex < spaces.count {
                    addTask(at: nextIndex)
                    nextIndex += 1
                }
            }

            return results.sorted { $0.0 < $1.0 }.map(\.1)
        }
    }

    private func makeSummary(account: LinkedAccount, space: ChatSpace) async -> ConversationSummary {
        let memberNames = await memberDisplayNames(accountId: account.id, spaceName: space.name)
        let title = resolveSpaceTitle(
            space: space,
            memberNames: memberNames,
            selfUserName: account.id.chatUserName
        )

        let preview: String
        let activity: Date
        if let messages = try? await api.listMessages(
            accountId: account.id,
            spaceName: space.name,
            pageSize: 1
        ), let latest = messages.messages.first {
            let sender = resolveSenderName(latest.sender, memberNames: memberNames)
            let text = latest.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            preview = text.isEmpty ? "\(sender): (attachment)" : "\(sender): \(text)"
            activity = latest.createTime ?? space.lastActiveTime ?? .distantPast
        } else {
            preview = ""
            activity = space.lastActiveTime ?? .distantPast
        }

        return ConversationSummary(
            accountId: account.id,
            accountLabel: account.label,
            accountColorHex: account.colorHex,
            spaceName: space.name,
            title: title,
            lastMessagePreview: preview,
            lastActivityAt: activity,
            unreadCount: 0,
            isDirectMessage: space.isDirectMessage
        )
    }

    private func memberDisplayNames(accountId: AccountID, spaceName: String) async -> [String: String] {
        guard let response = try? await api.listMembers(
            accountId: accountId,
            spaceName: spaceName,
            showInvited: true
        ) else {
            return [:]
        }
        var map: [String: String] = [:]
        for membership in response.memberships {
            guard let member = membership.member, let name = member.name else { continue }
            if member.hasHumanReadableName,
               let label = member.displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
            {
                map[name] = label
            }
        }
        // Chat user-auth responses often omit displayName — resolve via People API.
        if let people {
            let missing = response.memberships.compactMap(\.member?.name).filter { map[$0] == nil }
            if let resolved = try? await people.displayNames(accountId: accountId, chatUserNames: missing) {
                for (key, value) in resolved { map[key] = value }
            }
        }
        return map
    }

    private func resolveSpaceTitle(
        space: ChatSpace,
        memberNames: [String: String],
        selfUserName: String
    ) -> String {
        let existing = space.resolvedTitle
        if !space.isDirectMessage { return existing }
        if existing != "DM", existing != space.name { return existing }
        // DM titles are often empty — use the other human member's name.
        let others = memberNames
            .filter { $0.key != selfUserName }
            .map(\.value)
            .filter { !$0.isEmpty }
        if others.count == 1 { return others[0] }
        if others.count > 1 { return others.sorted().joined(separator: ", ") }
        return existing
    }

    private func resolveSenderName(_ sender: ChatSender?, memberNames: [String: String]) -> String {
        guard let sender else { return "Someone" }
        if sender.hasHumanReadableName,
           let trimmed = sender.displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
        {
            return trimmed
        }
        if let name = sender.name, let mapped = memberNames[name], !mapped.isEmpty {
            return mapped
        }
        return "Someone"
    }

    private func listAllSpaces(accountId: AccountID) async throws -> [ChatSpace] {
        var spaces: [ChatSpace] = []
        var pageToken: String? = nil
        var pageCount = 0
        repeat {
            pageCount += 1
            if pageCount > maxSpacePages {
                throw InboxSyncError.spacePaginationLimitExceeded
            }
            let response = try await api.listSpaces(accountId: accountId, pageToken: pageToken)
            spaces.append(contentsOf: response.spaces)
            pageToken = response.nextPageToken
        } while pageToken != nil && !(pageToken?.isEmpty ?? true)
        return spaces
    }
}

/// In-memory cache used by tests and as a warm fallback before GRDB is wired.
public actor InMemoryConversationCache: ConversationCaching {
    private var rows: [ConversationSummary] = []

    public init() {}

    public func replaceConversations(_ rows: [ConversationSummary]) async throws {
        self.rows = rows
    }

    public func loadConversations() async throws -> [ConversationSummary] {
        rows
    }

    public func deleteConversations(accountId: AccountID) async throws {
        rows.removeAll { $0.accountId == accountId }
    }
}
