//  ImageLoaderKitTests.swift
//  ImageLoaderKitTests

import XCTest
@testable import ImageLoaderKit

final class ImageLoaderKitTests: XCTestCase {

    /// A bogus URL should resolve to `nil` rather than crashing, and the shared
    /// loader should be reachable as an actor.
    func testInvalidURLReturnsNil() async {
        let url = URL(string: "https://invalid.invalid/not-a-real-image.png")!
        let image = await ImageLoader.shared.image(from: url)
        XCTAssertNil(image)
    }
}
