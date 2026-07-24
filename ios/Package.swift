// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GoogleChatMulti",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
    ],
    products: [
        .library(name: "GoogleChatCore", targets: ["GoogleChatCore"]),
    ],
    targets: [
        .systemLibrary(
            name: "CSQLite",
            path: "Sources/CSQLite"
        ),
        .target(
            name: "GoogleChatCore",
            dependencies: ["CSQLite"],
            path: "Sources/GoogleChatCore",
            linkerSettings: [
                .linkedLibrary("sqlite3"),
            ]
        ),
        .testTarget(
            name: "GoogleChatCoreTests",
            dependencies: ["GoogleChatCore"],
            path: "Tests/GoogleChatCoreTests"
        ),
    ]
)
