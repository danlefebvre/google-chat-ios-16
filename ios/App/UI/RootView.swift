import SwiftUI
import GoogleChatCore

struct RootView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var banners: BannerBridge

    var body: some View {
        NavigationStack {
            HomeView()
        }
        .overlay(alignment: .top) {
            if let banner = banners.current {
                InAppBannerView(banner: banner) {
                    banners.dismiss()
                    Task {
                        if let row = model.conversations.first(where: {
                            $0.accountId == banner.accountId && $0.spaceName == banner.spaceName
                        }) {
                            await model.openConversation(row)
                        }
                    }
                }
                .padding()
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: banners.current?.id)
        .alert("Error", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
    }
}

struct InAppBannerView: View {
    let banner: InAppBanner
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 4) {
                Text(banner.title)
                    .font(.subheadline.weight(.semibold))
                Text(banner.preview)
                    .font(.footnote)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}
