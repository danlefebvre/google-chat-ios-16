import SwiftUI
import GoogleChatMultiCore

@main
struct GoogleChatMultiApp: App {
    @StateObject private var appModel = AppModel()

    init() {
        AppBootstrap.configureRelay()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appModel)
                .onOpenURL { url in
                    appModel.handleDeepLink(url)
                }
        }
    }
}
