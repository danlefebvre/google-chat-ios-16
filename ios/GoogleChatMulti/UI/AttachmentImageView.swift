import SwiftUI
import UIKit
import GoogleChatMultiCore

/// Downloads Chat attachment bytes via the media API and shows an image.
struct AttachmentImageView: View {
    let attachment: ChatAttachment
    let accountId: AccountID
    let tokenProvider: any TokenProviding

    @EnvironmentObject private var model: AppModel
    @State private var image: UIImage?
    @State private var loadError: LoadError?
    @State private var isLoading = false
    @State private var showFullScreen = false

    private enum LoadError: Equatable {
        case retryable(String)
        case nonRetryable(String)

        var message: String {
            switch self {
            case .retryable(let message), .nonRetryable(let message):
                return message
            }
        }

        var isRetryable: Bool {
            if case .retryable = self { return true }
            return false
        }
    }

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
            } else if let loadError {
                if loadError.isRetryable {
                    Button {
                        Task { await load(isRetry: true) }
                    } label: {
                        Label(loadError.message, systemImage: "exclamationmark.triangle")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Retries loading the image")
                } else {
                    Label(loadError.message, systemImage: "exclamationmark.triangle")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
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

    private func load(isRetry: Bool = false) async {
        guard image == nil, !isLoading else { return }
        guard let resource = attachment.mediaResourceName else {
            loadError = .nonRetryable(attachment.contentName ?? "Unsupported attachment")
            return
        }
        loadError = nil
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
                loadError = .nonRetryable(attachment.contentName ?? "Could not decode image")
            }
        } catch {
            AppLog.inbox.error(
                "attachment download failed: \(error.localizedDescription, privacy: .public)"
            )
            loadError = .retryable("Couldn't load image")
            if isRetry {
                model.banner = error.localizedDescription
            }
        }
    }
}
