//
//  AdSeekResolverTests.swift
//  AdSDKTests
//

import XCTest
@testable import AdSDK

final class AdSeekResolverTests: XCTestCase {

    private func cues(_ watched: Set<String> = []) -> [AdSeekResolver.Cue] {
        [
            AdSeekResolver.Cue(id: "b25", time: 25, isUnwatched: !watched.contains("b25")),
            AdSeekResolver.Cue(id: "b50", time: 50, isUnwatched: !watched.contains("b50")),
            AdSeekResolver.Cue(id: "b75", time: 75, isUnwatched: !watched.contains("b75")),
        ]
    }

    func testAllowedPolicyAlwaysSeeks() {
        let decision = AdSeekResolver.resolve(from: 0, to: 80, cues: cues(), policy: .allowed)
        XCTAssertEqual(decision, .seek(to: 80))
    }

    func testBackwardSeekNeverTriggersAd() {
        let decision = AdSeekResolver.resolve(from: 80, to: 10, cues: cues(), policy: .redirect)
        XCTAssertEqual(decision, .seek(to: 10))
    }

    func testRedirectPlaysFirstCrossedBreak() {
        let decision = AdSeekResolver.resolve(from: 0, to: 80, cues: cues(), policy: .redirect)
        XCTAssertEqual(decision, .playBreak(id: "b25", resumeAt: 80))
    }

    func testRedirectSkipsAlreadyWatchedBreaks() {
        // b25 already watched -> first crossed unwatched is b50.
        let decision = AdSeekResolver.resolve(from: 0, to: 80, cues: cues(["b25"]), policy: .redirect)
        XCTAssertEqual(decision, .playBreak(id: "b50", resumeAt: 80))
    }

    func testRedirectFromMidContent() {
        // Seeking from 30 -> 80 crosses b50 and b75; first is b50.
        let decision = AdSeekResolver.resolve(from: 30, to: 80, cues: cues(), policy: .redirect)
        XCTAssertEqual(decision, .playBreak(id: "b50", resumeAt: 80))
    }

    func testRedirectNoCrossingSeeksDirectly() {
        // 0 -> 20 crosses no cue.
        let decision = AdSeekResolver.resolve(from: 0, to: 20, cues: cues(), policy: .redirect)
        XCTAssertEqual(decision, .seek(to: 20))
    }

    func testIterativeMultiBreakResolution() {
        // Simulate the coordinator loop: play each crossed break, mark watched,
        // re-resolve until it finally lands at the destination.
        var watched: Set<String> = []
        var current: TimeInterval = 0
        let target: TimeInterval = 80
        var played: [String] = []

        for _ in 0..<10 {
            let decision = AdSeekResolver.resolve(from: current, to: target, cues: cues(watched), policy: .redirect)
            switch decision {
            case .seek(let to):
                XCTAssertEqual(to, target)
                XCTAssertEqual(played, ["b25", "b50", "b75"])
                return
            case .playBreak(let id, let resumeAt):
                XCTAssertEqual(resumeAt, target)
                played.append(id)
                watched.insert(id)
                // Coordinator advances the playhead to the break it just played.
                current = cues().first { $0.id == id }!.time
            }
        }
        XCTFail("Did not converge to destination")
    }
}
