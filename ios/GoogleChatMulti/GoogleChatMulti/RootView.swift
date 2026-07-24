import SwiftUI
import GoogleChatCore

struct RootView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        NavigationStack {
            HomeView()
                .navigationTitle("Chats")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        NavigationLink("Accounts") {
                            AccountManagerView()
                        }
                    }
                }
        }
        .task {
            await appModel.refresh()
        }
        .alert("Error", isPresented: Binding(
            get: { appModel.errorMessage != nil },
            set: { if !$0 { appModel.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(appModel.errorMessage ?? "")
        }
    }
}
