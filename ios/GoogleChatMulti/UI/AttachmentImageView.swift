import SwiftUI
import UIKit
import GoogleChatMultiCore

/// Downloads Chat attachment bytes via the media API and shows an image.
struct AttachmentImageView: View {
    let attachment: ChatAttachment
    let accountId: AccountID
    let tokenProvider: any TokenProviding

    @State private var image: UIImage?
    @State private var errorText: String?
    @State private var isLoading = false
    @State private var showFullScreen = false

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 260, maxHeight: 260)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .onTapGesture { showFullScreen = true }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityHint("Shows the image full screen")
                    .fullScreenCover(isPresented: $showFullScreen) {
                        FullScreenImageViewer(image: image)
                    }
            } else if isLoading {
                ProgressView()
                    .frame(width: 80, height: 80)
            } else if let errorText {
                Label(errorText, systemImage: "exclamationmark.triangle")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Label(attachment.contentName ?? "Attachment", systemImage: "photo")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .task(id: attachment.mediaResourceName) {
            await load()
        }
    }

    private func load() async {
        guard image == nil, !isLoading else { return }
        guard let resource = attachment.mediaResourceName else {
            errorText = attachment.contentName ?? "Unsupported attachment"
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let token = try await tokenProvider.accessToken(for: accountId)
            let data = try await MediaClient().downloadAttachment(
                resourceName: resource,
                accessToken: token
            )
            if let ui = UIImage(data: data) {
                image = ui
            } else {
                errorText = attachment.contentName ?? "Could not decode image"
            }
        } catch {
            AppLog.inbox.error(
                "attachment download failed: \(error.localizedDescription, privacy: .public)"
            )
            errorText = "Couldn't load image"
        }
    }
}
