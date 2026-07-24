import Foundation
import SwiftUI
import GoogleChatCore

@MainActor
final class AppModel: ObservableObject {
    @Published var accounts: [AccountAuthorization] = []
    @Published var conversations: [ConversationSummary] = []
    @Published var selectedAccountFilter: AccountID?
    @Published var searchQuery: String = ""
    @Published var path: [AppRoute] = []
    @Published var banner: InAppBanner?
    @Published var errorMessage: String?

    let authStore: AuthStore
    let conversationStore: ConversationStore
    let relayBaseURL: URL
    let relayAPIToken: String
    private var foregroundPollTask: Task<Void, Never>?

    enum AppRoute: Hashable {
        case thread(accountID: AccountID, spaceName: String, title: String, accountLabel: String)
        case accounts
    }

    init(
        authStore: AuthStore? = nil,
        conversationStore: ConversationStore? = nil,
        relayBaseURL: URL = URL(string: ProcessInfo.processInfo.environment["RELAY_BASE_URL"] ?? "http://127.0.0.1:8080")!,
        relayAPIToken: String = ProcessInfo.processInfo.environment["RELAY_API_TOKEN"] ?? ""
    ) {
        #if os(iOS)
        self.authStore = authStore ?? KeychainAuthStore()
        #else
        self.authStore = authStore ?? InMemoryAuthStore()
        #endif
        if let conversationStore {
            self.conversationStore = conversationStore
        } else {
            let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let path = dir.appendingPathComponent("chat-cache.sqlite").path
            self.conversationStore = (try? SQLiteConversationStore(path: path)) ?? InMemoryConversationStore()
        }
        self.relayBaseURL = relayBaseURL
        self.relayAPIToken = relayAPIToken
    }

    var visibleConversations: [ConversationSummary] {
        let merged = InboxMerger.merge(conversations)
        let filtered = InboxMerger.filter(merged, accountID: selectedAccountFilter)
        return InboxMerger.search(filtered, query: searchQuery)
    }

    func bootstrap() async {
        do {
            accounts = try await authStore.all()
            conversations = try await conversationStore.allConversations()
            await refreshAllAccounts()
            startForegroundPolling()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshAllAccounts() async {
        for account in accounts {
            await refresh(account: account)
        }
        conversations = (try? await conversationStore.allConversations()) ?? conversations
    }

    func refresh(account: AccountAuthorization) async {
        let client = ChatAPIClient {
            let provider = TokenProvider(store: self.authStore, refresher: OAuthTokenRefresher())
            return try await provider.validAccessToken(for: account.accountID)
        }
        let sync = AccountSync(client: client, store: conversationStore, accountLabel: account.label)
        do {
            try await sync.syncSpaces(accountID: account.accountID)
        } catch {
            errorMessage = "\(account.label): \(error.localizedDescription)"
        }
    }

    func handle(url: URL) {
        do {
            let link = try DeepLink(url: url)
            if case let .openSpace(accountID, spaceName) = link {
                let title = conversations.first(where: { $0.accountID == accountID && $0.spaceName == spaceName })?.title
                    ?? spaceName
                let label = accounts.first(where: { $0.accountID == accountID })?.label ?? "Account"
                path.append(.thread(accountID: accountID, spaceName: spaceName, title: title, accountLabel: label))
            }
        } catch {
            errorMessage = "Invalid link"
        }
    }

    func removeAccount(_ accountID: AccountID) async {
        let relay = RelayClient(baseURL: relayBaseURL, apiToken: relayAPIToken)
        let coordinator = AccountRemovalCoordinator(
            relay: relay,
            authStore: authStore,
            conversationStore: conversationStore
        )
        do {
            try await coordinator.remove(accountID: accountID)
            accounts = try await authStore.all()
            conversations = try await conversationStore.allConversations()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func showFallbackBanner(title: String, body: String) {
        banner = InAppBanner(title: title, body: body)
    }

    private func startForegroundPolling() {
        foregroundPollTask?.cancel()
        foregroundPollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 45_000_000_000)
                guard let self else { return }
                let before = self.conversations
                await self.refreshAllAccounts()
                if let newest = self.conversations.max(by: { $0.lastActivityAt < $1.lastActivityAt }),
                   let old = before.first(where: { $0.compositeID == newest.compositeID }),
                   newest.lastActivityAt > old.lastActivityAt {
                    self.showFallbackBanner(
                        title: "[\(newest.accountLabel)] \(newest.title)",
                        body: newest.lastMessagePreview
                    )
                }
            }
        }
    }
}

struct InAppBanner: Equatable, Identifiable {
    let id = UUID()
    let title: String
    let body: String
}

struct OAuthTokenRefresher: TokenRefresher {
    func refresh(refreshToken: String) async throws -> (accessToken: String, expiresAt: Date) {
        // Real implementation exchanges refresh tokens with Google's token endpoint.
        // Kept as a seam so UI can boot without embedding client secrets in tests.
        throw TokenRefreshError.notConfigured
    }
}

enum TokenRefreshError: Error {
    case notConfigured
}
