// swift-tools-version: 5.9
//
//  PlayerSDK
//
//  A small, self-contained video-player library built on AVFoundation. It exposes
//  a host `UIView` the client embeds, a rich delegate callback surface, and a
//  ready-to-present trailer popup — with custom controls (play/pause, scrubber,
//  ±10s, fullscreen, volume/mute).
//
import PackageDescription

let package = Package(
    name: "PlayerSDK",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(name: "PlayerSDK", targets: ["PlayerSDK"])
    ],
    targets: [
        .target(name: "PlayerSDK"),
        .testTarget(name: "PlayerSDKTests", dependencies: ["PlayerSDK"])
    ]
)
