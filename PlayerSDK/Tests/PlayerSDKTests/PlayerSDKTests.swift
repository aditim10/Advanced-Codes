//
//  PlayerSDKTests.swift
//  PlayerSDKTests
//
//  Unit tests for the player SDK. They never depend on real network playback:
//  the time math is pure, and the "dummy video play" test asserts the load state
//  machine + delegate callbacks (which fire synchronously) rather than waiting on
//  real frames. Run on an iOS Simulator via the PlayerSDK scheme.
//

import XCTest
import AVFoundation
@testable import PlayerSDK

// MARK: - Spy delegate

/// Records every callback so tests can assert what the player reported.
final class SpyVideoPlayerDelegate: VideoPlayerDelegate {
    private(set) var states: [VideoPlayerState] = []
    private(set) var didPlay = false
    private(set) var didPause = false
    private(set) var didFinish = false
    private(set) var seekedTo: TimeInterval?
    private(set) var lastVolume: (volume: Float, muted: Bool)?
    private(set) var fullscreenStates: [Bool] = []

    func videoPlayer(_ player: VideoPlayerView, didChangeState state: VideoPlayerState) { states.append(state) }
    func videoPlayerDidPlay(_ player: VideoPlayerView) { didPlay = true }
    func videoPlayerDidPause(_ player: VideoPlayerView) { didPause = true }
    func videoPlayerDidFinish(_ player: VideoPlayerView) { didFinish = true }
    func videoPlayer(_ player: VideoPlayerView, didSeekTo time: TimeInterval) { seekedTo = time }
    func videoPlayer(_ player: VideoPlayerView, didChangeVolume volume: Float, isMuted: Bool) {
        lastVolume = (volume, isMuted)
    }
    func videoPlayer(_ player: VideoPlayerView, didToggleFullscreen isFullscreen: Bool) {
        fullscreenStates.append(isFullscreen)
    }
}

// A dummy stand-in URL — no real request is made in these tests.
private let dummyURL = URL(string: "https://example.com/trailer.m3u8")!

// MARK: - Time math (pure, fully deterministic)

final class VideoTimeTests: XCTestCase {

    func testClampKeepsValueInBounds() {
        XCTAssertEqual(VideoTime.clamp(-5, duration: 100), 0)
        XCTAssertEqual(VideoTime.clamp(50, duration: 100), 50)
        XCTAssertEqual(VideoTime.clamp(150, duration: 100), 100)
    }

    func testClampHandlesInvalidDurationAndNaN() {
        XCTAssertEqual(VideoTime.clamp(10, duration: 0), 0)
        XCTAssertEqual(VideoTime.clamp(10, duration: .nan), 0)
        XCTAssertEqual(VideoTime.clamp(.nan, duration: 100), 0)
    }

    func testSkipForwardClampsAtEnd() {
        // +10 from 95s in a 100s clip -> clamps to 100, not 105.
        XCTAssertEqual(VideoTime.target(from: 95, offset: 10, duration: 100), 100)
    }

    func testSkipBackwardClampsAtZero() {
        XCTAssertEqual(VideoTime.target(from: 4, offset: -10, duration: 100), 0)
    }

    func testProgressIsRatio() {
        XCTAssertEqual(VideoTime.progress(current: 25, duration: 100), 0.25, accuracy: 0.0001)
        XCTAssertEqual(VideoTime.progress(current: 10, duration: 0), 0) // unknown duration
    }

    func testFormatting() {
        XCTAssertEqual(VideoTime.formatted(0), "0:00")
        XCTAssertEqual(VideoTime.formatted(9), "0:09")
        XCTAssertEqual(VideoTime.formatted(75), "1:15")
        XCTAssertEqual(VideoTime.formatted(3661), "1:01:01")
        XCTAssertEqual(VideoTime.formatted(.nan), "0:00")
    }
}

// MARK: - Configuration

final class VideoPlayerConfigurationTests: XCTestCase {

    func testDefaults() {
        let config = VideoPlayerConfiguration(url: dummyURL)
        XCTAssertTrue(config.autoPlay)
        XCTAssertFalse(config.startsMuted)
        XCTAssertFalse(config.loops)
        XCTAssertEqual(config.skipInterval, 10)
        XCTAssertNil(config.title)
    }

    func testOverrides() {
        let config = VideoPlayerConfiguration(
            url: dummyURL, title: "Frieren", autoPlay: false,
            startsMuted: true, loops: true, skipInterval: 15)
        XCTAssertEqual(config.title, "Frieren")
        XCTAssertFalse(config.autoPlay)
        XCTAssertTrue(config.startsMuted)
        XCTAssertTrue(config.loops)
        XCTAssertEqual(config.skipInterval, 15)
    }
}

// MARK: - Player view behaviour (no real playback)

@MainActor
final class VideoPlayerViewTests: XCTestCase {

    func testLoadingDummyVideoEntersLoadingStateAndNotifiesDelegate() {
        let player = VideoPlayerView()
        let spy = SpyVideoPlayerDelegate()
        player.delegate = spy

        player.load(VideoPlayerConfiguration(url: dummyURL, title: "Dummy", autoPlay: false))

        // The load state machine is synchronous up to .loading (no network needed).
        XCTAssertEqual(player.state, .loading)
        XCTAssertEqual(spy.states.last, .loading)
    }

    func testStartsMutedConfigurationIsApplied() {
        let player = VideoPlayerView()
        player.load(VideoPlayerConfiguration(url: dummyURL, startsMuted: true, autoPlay: false))
        XCTAssertTrue(player.isMuted)
    }

    func testSetVolumeUnmutesAndReportsToDelegate() {
        let player = VideoPlayerView()
        let spy = SpyVideoPlayerDelegate()
        player.delegate = spy
        player.load(VideoPlayerConfiguration(url: dummyURL, startsMuted: true, autoPlay: false))

        player.setVolume(0.5)

        XCTAssertFalse(player.isMuted)
        XCTAssertEqual(spy.lastVolume?.volume, 0.5)
        XCTAssertEqual(spy.lastVolume?.muted, false)
    }

    func testToggleMuteReportsToDelegate() {
        let player = VideoPlayerView()
        let spy = SpyVideoPlayerDelegate()
        player.delegate = spy
        player.load(VideoPlayerConfiguration(url: dummyURL, autoPlay: false))

        XCTAssertFalse(player.isMuted)
        player.toggleMute()
        XCTAssertTrue(player.isMuted)
        XCTAssertEqual(spy.lastVolume?.muted, true)
    }
}
