// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "GoogleChatMulti",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
    ],
    products: [
        .library(name: "GoogleChatCore", targets: ["GoogleChatCore"]),
    ],
    targets: [
        .target(
            name: "GoogleChatCore",
            path: "Sources/GoogleChatCore"
        ),
        .testTarget(
            name: "GoogleChatCoreTests",
            dependencies: ["GoogleChatCore"],
            path: "Tests/GoogleChatCoreTests"
        ),
    ]
)
