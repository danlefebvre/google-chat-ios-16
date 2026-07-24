import SwiftUI
import GoogleChatCore

struct RootView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        NavigationStack(path: $appModel.path) {
            InboxView()
                .navigationDestination(for: AppModel.AppRoute.self) { route in
                    switch route {
                    case let .thread(accountID, spaceName, title, accountLabel):
                        ThreadView(
                            accountID: accountID,
                            spaceName: spaceName,
                            title: title,
                            accountLabel: accountLabel
                        )
                    case .accounts:
                        AccountManagerView()
                    }
                }
        }
        .task { await appModel.bootstrap() }
        .overlay(alignment: .top) {
            if let banner = appModel.banner {
                InAppBannerView(banner: banner) {
                    appModel.banner = nil
                }
                .padding()
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: appModel.banner?.id)
        .alert("Error", isPresented: Binding(
            get: { appModel.errorMessage != nil },
            set: { if !$0 { appModel.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { appModel.errorMessage = nil }
        } message: {
            Text(appModel.errorMessage ?? "")
        }
    }
}

struct InAppBannerView: View {
    let banner: InAppBanner
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(banner.title).font(.headline)
            Text(banner.body).font(.subheadline).lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial)
        .onTapGesture(perform: onDismiss)
        .accessibilityAddTraits(.isButton)
    }
}
