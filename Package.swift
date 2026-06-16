// swift-tools-version: 5.9
import PackageDescription

// Swift Package manifest for the AnimeApp codebase.
//
// The app itself is a UIKit + Storyboards iOS app, so this package exposes the
// source as an iOS library target. It lets the code be built / type-checked with
// Swift Package Manager and consumed as a module.
//
// Because it depends on UIKit, build it for an iOS destination, e.g.:
//   xcodebuild -scheme AnimeApp -destination 'generic/platform=iOS' \
//     -derivedDataPath .build build
// (plain `swift build` targets macOS, where UIKit is unavailable.)
let package = Package(
    name: "AnimeApp",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "AnimeApp",
            targets: ["AnimeApp"]
        )
    ],
    targets: [
        .target(
            name: "AnimeApp",
            path: "AnimeApp",
            exclude: [
                "Info.plist"
            ],
            resources: [
                .process("Resources/Main.storyboard"),
                .process("Resources/LaunchScreen.storyboard"),
                .process("Resources/Assets.xcassets")
            ]
        )
    ]
)
