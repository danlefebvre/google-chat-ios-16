// swift-tools-version: 6.0
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
            path: "Sources/GoogleChatCore",
            swiftSettings: [
                .swiftLanguageMode(.v5),
            ]
        ),
        .testTarget(
            name: "GoogleChatCoreTests",
            dependencies: ["GoogleChatCore"],
            path: "Tests/GoogleChatCoreTests",
            swiftSettings: [
                .swiftLanguageMode(.v5),
            ]
        ),
    ]
)
