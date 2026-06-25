// swift-tools-version: 5.9
//
//  ImageLoaderKit
//
//  A tiny, self-contained async image loader with an in-memory cache and
//  request de-duplication. Has no third-party dependencies and knows nothing
//  about the app — any client can load and cache remote images through it.
//
import PackageDescription

let package = Package(
    name: "ImageLoaderKit",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(name: "ImageLoaderKit", targets: ["ImageLoaderKit"])
    ],
    targets: [
        .target(name: "ImageLoaderKit"),
        .testTarget(name: "ImageLoaderKitTests", dependencies: ["ImageLoaderKit"])
    ]
)
