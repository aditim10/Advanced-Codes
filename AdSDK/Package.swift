// swift-tools-version: 5.9
//
//  AdSDK
//
//  A self-contained client-side ad library: full VMAP + VAST parsing, mid-roll
//  scheduling, ad-tier filtering, a seek policy with snap-to-ad / snap-back
//  behaviour, VAST tracking, and HLS stream metrics.
//
//  AdSDK has NO dependency on any concrete video player. It defines the
//  `AdContentPlayer` abstraction and the host app supplies an adapter for its real
//  player (e.g. PlayerSDK), so the two SDKs stay fully decoupled and independently
//  reusable/testable.
//
import PackageDescription

let package = Package(
    name: "AdSDK",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(name: "AdSDK", targets: ["AdSDK"])
    ],
    targets: [
        .target(
            name: "AdSDK",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(name: "AdSDKTests", dependencies: ["AdSDK"])
    ]
)
