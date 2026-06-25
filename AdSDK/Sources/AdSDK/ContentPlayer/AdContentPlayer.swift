//
//  AdContentPlayer.swift
//  AdSDK
//
//  The abstraction AdSDK depends on instead of a concrete video player. This is
//  the seam that decouples AdSDK from PlayerSDK entirely: AdSDK owns these
//  protocols, and the host app supplies an adapter that conforms its real player
//  (e.g. `PlayerSDK.VideoPlayerView`) to them. As a result AdSDK has no compile-
//  time dependency on any specific player implementation.
//
//  `AdContentPlayer` is what the coordinator *drives* (load/play/pause/seek, plus
//  the view to anchor the ad overlay to and the item to read metrics from).
//  `AdContentPlayerObserver` is what the coordinator *listens to* (progress,
//  readiness, completion) and how it intercepts seeks to redirect to an ad break.
//

import UIKit
import AVFoundation

/// A content player AdSDK can control. Implemented by a host-supplied adapter.
@MainActor
public protocol AdContentPlayer: AnyObject {

    /// The view the ad overlay is anchored over (typically the player's own view).
    var adContentView: UIView { get }

    /// Current playback position, in seconds.
    var currentTime: TimeInterval { get }

    /// Total content duration in seconds (0 until known).
    var contentDuration: TimeInterval { get }

    /// The underlying player item, used only for stream-metrics collection.
    var currentPlayerItem: AVPlayerItem? { get }

    /// The coordinator that observes playback and intercepts seeks. The adapter
    /// forwards its player callbacks here.
    var adObserver: AdContentPlayerObserver? { get set }

    /// Loads and begins playing content.
    func loadContent(url: URL, title: String?)

    func playContent()
    func pauseContent()

    /// Marks ad-break cue points (absolute content times in seconds) on the
    /// player's scrubber, OTT-style. Pass an empty array to clear.
    func setAdCueMarkers(_ times: [TimeInterval])

    /// Seeks **without** ad interception — used to resume at the viewer's
    /// destination after an ad break has played.
    func seekContent(to time: TimeInterval)
}

/// What AdSDK needs to hear from the content player. The host adapter calls these
/// in response to its underlying player's events.
@MainActor
public protocol AdContentPlayerObserver: AnyObject {

    /// The content became playable; `duration` is its total length.
    func contentPlayerDidBecomeReady(duration: TimeInterval)

    /// Periodic content playback progress.
    func contentPlayerDidProgress(to time: TimeInterval, duration: TimeInterval)

    /// Content playback started/resumed (used to measure time-to-first-frame).
    func contentPlayerDidStartPlaying()

    /// Content reached the end.
    func contentPlayerDidFinish()

    /// Asked before a user-initiated seek. Return `true` to allow it; `false` lets
    /// AdSDK take over (play a crossed ad break, then resume at the destination).
    func contentPlayer(shouldSeekTo target: TimeInterval) -> Bool
}
