import Foundation
import OSLog

enum AppLog {
    static let general = Logger(subsystem: "com.googlechatmulti.app", category: "app")
    static let relay = Logger(subsystem: "com.googlechatmulti.app", category: "relay")
    static let auth = Logger(subsystem: "com.googlechatmulti.app", category: "auth")
    static let inbox = Logger(subsystem: "com.googlechatmulti.app", category: "inbox")
}
