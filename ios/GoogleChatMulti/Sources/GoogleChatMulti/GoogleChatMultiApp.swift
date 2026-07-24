import SwiftUI
import GoogleChatCore

@main
struct GoogleChatMultiApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .onOpenURL { url in
                    appState.handleDeepLink(url)
                }
        }
    }
}
