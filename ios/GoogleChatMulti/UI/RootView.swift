import SwiftUI
import GoogleChatMultiCore

struct RootView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack(path: $model.path) {
            InboxView()
                .navigationDestination(for: AppRoute.self) { route in
                    switch route {
                    case .thread(let compositeId):
                        ThreadView(compositeId: compositeId)
                    case .accounts:
                        AccountManagerView()
                    }
                }
        }
        .onChange(of: scenePhase) { phase in
            // Refresh the unified inbox whenever the app returns to the foreground.
            if phase == .active {
                Task {
                    await model.acknowledgeNotifications()
                    await model.refresh()
                }
            }
        }
        .overlay(alignment: .top) {
            if let banner = model.banner {
                Text(banner)
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(Color("BannerBackground"))
                    .foregroundStyle(Color("BannerText"))
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onTapGesture { model.banner = nil }
                    .task(id: banner) {
                        try? await Task.sleep(nanoseconds: 4_000_000_000)
                        model.banner = nil
                    }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: model.banner)
    }
}
