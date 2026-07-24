// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "GoogleChatMultiCore",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
    ],
    products: [
        .library(name: "GoogleChatMultiCore", targets: ["GoogleChatMultiCore"]),
    ],
    targets: [
        .target(
            name: "GoogleChatMultiCore",
            path: "Sources"
        ),
        .testTarget(
            name: "GoogleChatMultiCoreTests",
            dependencies: ["GoogleChatMultiCore"],
            path: "Tests"
        ),
    ]
)
