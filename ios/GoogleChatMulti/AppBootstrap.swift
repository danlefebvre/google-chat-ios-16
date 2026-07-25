import Foundation

enum AppBootstrap {
    /// Configure the relay client from `RELAY_BASE_URL` only.
    /// The shared `ADMIN_TOKEN` must stay server-side — never ship it in the app bundle.
    static func configureRelay() {
        guard
            let base = Bundle.main.object(forInfoDictionaryKey: "RELAY_BASE_URL") as? String
        else {
            AppLog.relay.error("RELAY_BASE_URL missing from Info.plist")
            assertionFailure("RELAY_BASE_URL missing from Info.plist")
            return
        }
        let trimmed = base.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            let url = URL(string: trimmed),
            !trimmed.isEmpty,
            !trimmed.contains("YOUR_RELAY_HOST"),
            url.scheme == "https" || url.scheme == "http"
        else {
            AppLog.relay.error("RELAY_BASE_URL is invalid: \(base, privacy: .public)")
            assertionFailure("RELAY_BASE_URL is invalid: \(base)")
            return
        }
        RelayAdminClient.configure(baseURL: url)
        AppLog.relay.info("Relay configured → \(url.absoluteString, privacy: .public)")
    }
}
