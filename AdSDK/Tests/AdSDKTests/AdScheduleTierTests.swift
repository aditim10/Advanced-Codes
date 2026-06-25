//
//  AdScheduleTierTests.swift
//  AdSDKTests
//

import XCTest
@testable import AdSDK

final class AdScheduleTierTests: XCTestCase {

    private func makeVMAP() -> VMAP {
        let source = AdSource.vast(VAST())
        return VMAP(adBreaks: [
            AdBreak(timeOffset: .percentage(0.25), breakId: "b25", adSource: source),
            AdBreak(timeOffset: .percentage(0.50), breakId: "b50", adSource: source),
            AdBreak(timeOffset: .percentage(0.75), breakId: "b75", adSource: source),
        ])
    }

    func testAdSupportedKeepsAllBreaks() {
        let schedule = AdSchedule(vmap: makeVMAP(), contentDuration: 100, tier: .adSupported)
        XCTAssertEqual(schedule.breaks.count, 3)
        XCTAssertEqual(schedule.breaks.map(\.scheduledTime), [25, 50, 75])
        XCTAssertNil(schedule.breaks.first?.maxAds)
    }

    func testAdLiteKeepsOnlyFirstBreakWithOneAd() {
        let schedule = AdSchedule(vmap: makeVMAP(), contentDuration: 100, tier: .adLite)
        XCTAssertEqual(schedule.breaks.count, 1)
        XCTAssertEqual(schedule.breaks.first?.id, "b25")
        XCTAssertEqual(schedule.breaks.first?.maxAds, 1)
    }

    func testAdFreeDropsAllBreaks() {
        let schedule = AdSchedule(vmap: makeVMAP(), contentDuration: 100, tier: .adFree)
        XCTAssertTrue(schedule.breaks.isEmpty)
    }

    func testBreaksOutsideDurationAreDropped() {
        let vmap = VMAP(adBreaks: [
            AdBreak(timeOffset: .seconds(0), breakId: "preish", adSource: .vast(VAST())),
            AdBreak(timeOffset: .seconds(40), breakId: "mid", adSource: .vast(VAST())),
            AdBreak(timeOffset: .seconds(500), breakId: "beyond", adSource: .vast(VAST())),
        ])
        let schedule = AdSchedule(vmap: vmap, contentDuration: 100, tier: .adSupported)
        XCTAssertEqual(schedule.breaks.map(\.id), ["mid"])
    }
}
