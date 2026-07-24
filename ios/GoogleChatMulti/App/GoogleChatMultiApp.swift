import SwiftUI
import GoogleChatCore

@main
struct GoogleChatMultiApp: App {
    @StateObject private var appModel = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appModel)
                .onOpenURL { url in
                    appModel.handle(url: url)
                }
        }
    }
}
