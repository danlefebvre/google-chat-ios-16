import SwiftUI
import GoogleChatCore

@main
struct GoogleChatMultiApp: App {
    @StateObject private var appModel: AppModel

    init() {
        let store = KeychainAccountStore()
        _appModel = StateObject(wrappedValue: (try? AppModel(accountStore: store)) ?? AppModel.fallback())
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appModel)
                .onOpenURL { url in
                    Task { @MainActor in
                        _ = try? appModel.openDeepLink(url)
                    }
                }
        }
    }
}

private extension AppModel {
    static func fallback() -> AppModel {
        try! AppModel(accountStore: InMemoryAccountStore())
    }
}
