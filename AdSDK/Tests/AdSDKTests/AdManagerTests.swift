//
//  AdManagerTests.swift
//  AdSDKTests
//

import XCTest
@testable import AdSDK

final class AdManagerTests: XCTestCase {

    private func makeManager(policy: SeekAdPolicy) -> AdManager {
        let source = AdSource.vast(VAST())
        let vmap = VMAP(adBreaks: [
            AdBreak(timeOffset: .percentage(0.25), breakId: "b25", adSource: source),
            AdBreak(timeOffset: .percentage(0.50), breakId: "b50", adSource: source),
            AdBreak(timeOffset: .percentage(0.75), breakId: "b75", adSource: source),
        ])
        let schedule = AdSchedule(vmap: vmap, contentDuration: 100, tier: .adSupported)
        return AdManager(schedule: schedule, seekPolicy: policy)
    }

    func testMidRollDueTriggerAndConsumption() {
        let manager = makeManager(policy: .redirect)

        XCTAssertEqual(manager.dueBreak(at: 26)?.id, "b25")
        manager.markBreakWatched(id: "b25")
        // b25 watched -> no longer due near its cue.
        XCTAssertNil(manager.dueBreak(at: 26))
        // The next break becomes due once playback reaches it.
        XCTAssertEqual(manager.dueBreak(at: 51)?.id, "b50")
    }

    func testRedirectSeekReturnsBreak() {
        let manager = makeManager(policy: .redirect)
        let decision = manager.resolveSeek(from: 0, to: 80)
        XCTAssertEqual(decision, .playBreak(id: "b25", resumeAt: 80))
        // The brain does NOT auto-consume on redirect (the overlay drives that).
        XCTAssertTrue(manager.hasUnwatchedBreaks)
    }

    func testAllowedSeekConsumesCrossedBreaks() {
        let manager = makeManager(policy: .allowed)
        let decision = manager.resolveSeek(from: 0, to: 80)
        XCTAssertEqual(decision, .seek(to: 80))
        // All three crossed breaks are marked skipped (consumed).
        XCTAssertFalse(manager.hasUnwatchedBreaks)
        XCTAssertNil(manager.dueBreak(at: 26))
    }

    func testAllowedSeekOnlyConsumesCrossedBreaks() {
        let manager = makeManager(policy: .allowed)
        _ = manager.resolveSeek(from: 0, to: 55) // crosses b25, b50 (not b75)
        XCTAssertEqual(manager.adBreak(id: "b75")?.state, .unwatched)
        XCTAssertTrue(manager.hasUnwatchedBreaks)
    }
}
