// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GoogleChatCore",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
    ],
    products: [
        .library(name: "GoogleChatCore", targets: ["GoogleChatCore"]),
    ],
    targets: [
        .target(name: "GoogleChatCore"),
        .testTarget(
            name: "GoogleChatCoreTests",
            dependencies: ["GoogleChatCore"]
        ),
    ]
)
