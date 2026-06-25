// swift-tools-version: 5.9
//
//  AnalyticsKit
//
//  The reusable analytics *event bus* infrastructure: the `AnalyticsEvent` and
//  `AnalyticsProvider` contracts plus the `AnalyticsManager` publisher/subscriber
//  hub. It is deliberately client-agnostic — concrete events and provider/SDK
//  adapters live in the consuming app, which registers them at bootstrap.
//
import PackageDescription

let package = Package(
    name: "AnalyticsKit",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(name: "AnalyticsKit", targets: ["AnalyticsKit"])
    ],
    targets: [
        .target(name: "AnalyticsKit"),
        .testTarget(name: "AnalyticsKitTests", dependencies: ["AnalyticsKit"])
    ]
)
