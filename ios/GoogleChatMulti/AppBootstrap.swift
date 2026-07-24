import Foundation

enum AppBootstrap {
    static func configureRelay() {
        guard
            let base = Bundle.main.object(forInfoDictionaryKey: "RELAY_BASE_URL") as? String,
            let url = URL(string: base),
            let token = Bundle.main.object(forInfoDictionaryKey: "RELAY_ADMIN_TOKEN") as? String,
            !token.isEmpty,
            !base.contains("YOUR_RELAY_HOST")
        else {
            return
        }
        RelayAdminClient.configure(baseURL: url, adminToken: token)
    }
}
