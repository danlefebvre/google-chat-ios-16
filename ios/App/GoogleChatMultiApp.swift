import SwiftUI
import GoogleChatCore

@main
struct GoogleChatMultiApp: App {
    @StateObject private var model: AppModel
    @StateObject private var bannerBridge: BannerBridge

    init() {
        let auth: AuthStore = KeychainAuthStore()
        let cacheDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("GoogleChatMulti", isDirectory: true)
        let conversationStore: ConversationStore =
            (try? JSONConversationStore(directory: cacheDir)) ?? InMemoryConversationStore()
        let banners = InAppBannerCenter()
        let relayURL = ProcessInfo.processInfo.environment["RELAY_BASE_URL"].flatMap(URL.init(string:))
        _model = StateObject(wrappedValue: AppModel(
            authStore: auth,
            conversationStore: conversationStore,
            banners: banners,
            relayBaseURL: relayURL
        ))
        _bannerBridge = StateObject(wrappedValue: BannerBridge(center: banners))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .environmentObject(bannerBridge)
                .onOpenURL { url in
                    Task { await model.handleDeepLink(url) }
                }
                .task {
                    await model.syncAll()
                }
        }
    }
}
