// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ConcurrentAPI",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        // The library — what other packages import
        .library(
            name: "ConcurrentAPI",
            targets: ["ConcurrentAPI"]
        ),
        // The demo executable — run with `swift run ConcurrentAPIDemo`
        .executable(
            name: "ConcurrentAPIDemo",
            targets: ["ConcurrentAPIDemo"]
        )
    ],
    targets: [
        .target(
            name: "ConcurrentAPI",
            path: "Sources/ConcurrentAPI"
        ),
        .executableTarget(
            name: "ConcurrentAPIDemo",
            dependencies: ["ConcurrentAPI"],
            path: "Sources/ConcurrentAPIDemo"
        ),
        .testTarget(
            name: "ConcurrentAPITests",
            dependencies: ["ConcurrentAPI"],
            path: "Tests/ConcurrentAPITests"
        ),
    ]
)
