// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GoogleChatMulti",
    platforms: [
        .iOS(.v16),
    ],
    products: [
        .library(name: "GoogleChatCore", targets: ["GoogleChatCore"]),
        .executable(name: "GoogleChatMulti", targets: ["GoogleChatMulti"]),
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "6.24.0"),
    ],
    targets: [
        .target(
            name: "GoogleChatCore",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift"),
            ],
            path: "Sources/GoogleChatCore"
        ),
        .executableTarget(
            name: "GoogleChatMulti",
            dependencies: ["GoogleChatCore"],
            path: "Sources/GoogleChatMulti"
        ),
        .testTarget(
            name: "GoogleChatCoreTests",
            dependencies: ["GoogleChatCore"],
            path: "Tests/GoogleChatCoreTests"
        ),
    ]
)
