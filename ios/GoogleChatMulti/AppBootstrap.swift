import Foundation

enum AppBootstrap {
    /// Configure the relay client from `RELAY_BASE_URL` only.
    /// The shared `ADMIN_TOKEN` must stay server-side — never ship it in the app bundle.
    static func configureRelay() {
        guard
            let base = Bundle.main.object(forInfoDictionaryKey: "RELAY_BASE_URL") as? String,
            let url = URL(string: base),
            !base.isEmpty,
            !base.contains("YOUR_RELAY_HOST")
        else {
            return
        }
        RelayAdminClient.configure(baseURL: url)
    }
}
