import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        NavigationStack {
            HomeView()
                .navigationDestination(item: $appModel.selectedConversation) { conversation in
                    ThreadView(conversation: conversation)
                }
        }
        .task {
            #if DEBUG
            if appModel.accounts.isEmpty && appModel.conversations.isEmpty {
                appModel.bootstrapPreviewData()
            }
            #endif
        }
        .overlay(alignment: .top) {
            if let banner = appModel.banner {
                Text(banner)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(.ultraThinMaterial)
                    .onTapGesture { appModel.banner = nil }
                    .padding(.top, 8)
            }
        }
    }
}
