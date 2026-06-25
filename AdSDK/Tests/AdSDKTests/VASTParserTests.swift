//
//  VASTParserTests.swift
//  AdSDKTests
//

import XCTest
@testable import AdSDK

final class VASTParserTests: XCTestCase {

    func testParsesInlineAd() throws {
        let vast = try XCTUnwrap(AdSampleSources.sampleVAST())
        XCTAssertEqual(vast.ads.count, 2)

        let inLine = try XCTUnwrap(vast.ads.first?.inLine)
        XCTAssertEqual(inLine.adTitle, "Standalone Sample Ad")
        XCTAssertEqual(inLine.adSystem, "AdSDK Sample")
        XCTAssertEqual(inLine.impressions.count, 1)
        XCTAssertEqual(inLine.errors.count, 1)

        let linear = try XCTUnwrap(inLine.linear)
        XCTAssertEqual(linear.duration, 15)
        XCTAssertEqual(linear.skipOffset, 5)
        XCTAssertEqual(linear.mediaFiles.count, 2)
    }

    func testPrefersHLSMediaFile() throws {
        let vast = try XCTUnwrap(AdSampleSources.sampleVAST())
        let linear = try XCTUnwrap(vast.ads.first?.inLine?.linear)
        let preferred = try XCTUnwrap(linear.preferredMediaFile)
        XCTAssertTrue(preferred.isHLS)
        XCTAssertEqual(preferred.url.pathExtension, "m3u8")
    }

    func testParsesFullTrackingEventSet() throws {
        let vast = try XCTUnwrap(AdSampleSources.sampleVAST())
        let linear = try XCTUnwrap(vast.ads.first?.inLine?.linear)

        XCTAssertEqual(linear.urls(for: .start).count, 1)
        XCTAssertEqual(linear.urls(for: .firstQuartile).count, 1)
        XCTAssertEqual(linear.urls(for: .midpoint).count, 1)
        XCTAssertEqual(linear.urls(for: .thirdQuartile).count, 1)
        XCTAssertEqual(linear.urls(for: .complete).count, 1)
        XCTAssertEqual(linear.urls(for: .skip).count, 1)
        XCTAssertEqual(linear.urls(for: .progress(offset: 3)).count, 1)
    }

    func testParsesVideoClicks() throws {
        let vast = try XCTUnwrap(AdSampleSources.sampleVAST())
        let clicks = try XCTUnwrap(vast.ads.first?.inLine?.linear?.videoClicks)
        XCTAssertEqual(clicks.clickThrough?.absoluteString, "https://example.com/landing/inline")
        XCTAssertEqual(clicks.clickTracking.count, 1)
    }

    func testParsesWrapperAd() throws {
        let vast = try XCTUnwrap(AdSampleSources.sampleVAST())
        let wrapper = try XCTUnwrap(vast.ads.last?.wrapper)
        XCTAssertEqual(wrapper.vastAdTagURI.absoluteString, "https://example.com/vast/redirect.xml")
        XCTAssertEqual(wrapper.impressions.count, 1)
        XCTAssertTrue(wrapper.followAdditionalWrappers)
        // Wrapper carries tracking-only creatives to be merged on resolution.
        let wrapperLinear = try XCTUnwrap(wrapper.creatives.first?.linear)
        XCTAssertEqual(wrapperLinear.urls(for: .start).count, 1)
        XCTAssertEqual(wrapperLinear.urls(for: .complete).count, 1)
    }

    func testPlayableAdPodBuild() throws {
        let vast = try XCTUnwrap(AdSampleSources.sampleVMAP()).adBreaks[0]
        guard case .vast(let inlineVAST) = vast.adSource else { return XCTFail() }
        let pod = PlayableAd.pod(from: inlineVAST, maxAds: nil)
        XCTAssertEqual(pod.count, 2)
        XCTAssertEqual(pod.first?.title, "Sample Mid-roll Ad A")
        XCTAssertTrue(pod.first?.isSkippable ?? false)

        // Ad-lite caps the pod to one ad.
        let capped = PlayableAd.pod(from: inlineVAST, maxAds: 1)
        XCTAssertEqual(capped.count, 1)
    }

    func testRejectsMalformedXML() {
        XCTAssertThrowsError(try VASTParser.parse(string: "<<<"))
    }
}
