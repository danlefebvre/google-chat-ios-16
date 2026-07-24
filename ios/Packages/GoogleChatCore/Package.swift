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
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "6.24.0"),
    ],
    targets: [
        .target(
            name: "GoogleChatCore",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift"),
            ]
        ),
        .testTarget(
            name: "GoogleChatCoreTests",
            dependencies: ["GoogleChatCore"]
        ),
    ]
)
