import SwiftUI
import GoogleChatCore

@main
struct GoogleChatMultiApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(model)
                .onOpenURL { url in
                    model.handleDeepLink(url)
                }
        }
    }
}
