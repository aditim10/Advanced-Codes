//
//  VideoPlaying.swift
//  PlayerSDK
//
//  The public *facade* for the player. Clients should program against this
//  protocol rather than the concrete `VideoPlayerView`, so the SDK's surface is
//  defined by an explicit contract (load / playback / seek / volume / fullscreen)
//  and the concrete UIView implementation can evolve behind it.
//
//      let player: VideoPlaying = VideoPlayerView()
//      player.delegate = self
//      player.load(VideoPlayerConfiguration(url: url, title: "Frieren"))
//      player.play()
//

import Foundation

/// Everything a host needs to drive and observe a video player, exposed as a
/// protocol so the concrete view type stays an implementation detail.
public protocol VideoPlaying: AnyObject {

    // MARK: Observation

    /// Receives all player events. See ``VideoPlayerDelegate``.
    var delegate: VideoPlayerDelegate? { get set }

    /// Optional hook that can intercept seeks (e.g. to redirect to an ad break).
    var seekCoordinator: VideoPlayerSeekCoordinator? { get set }

    // MARK: State (read-only)

    /// Current lifecycle state.
    var state: VideoPlayerState { get }

    /// Current playback position in seconds.
    var currentTime: TimeInterval { get }

    /// Total duration in seconds (0 until known).
    var duration: TimeInterval { get }

    /// Whether audio is currently muted.
    var isMuted: Bool { get }

    /// Whether the player is currently presented fullscreen.
    var isFullscreen: Bool { get }

    // MARK: Control

    /// Loads `configuration` and (if `autoPlay`) begins playback once ready.
    func load(_ configuration: VideoPlayerConfiguration)

    func play()
    func pause()
    func togglePlayPause()

    /// Seeks to an absolute `time` (seconds). When `force` is `false` the
    /// ``seekCoordinator`` may intercept; pass `true` to bypass it.
    func seek(to time: TimeInterval, force: Bool)

    func skipForward()
    func skipBackward()

    /// Marks ad cue points (absolute times in seconds) on the scrubber, OTT-style.
    /// Pass an empty array to clear. The player stays ad-agnostic — callers decide
    /// what the cues mean.
    func setCueMarkers(_ times: [TimeInterval])

    /// Sets the audio volume (`0...1`). Unmutes if currently muted.
    func setVolume(_ volume: Float)
    func toggleMute()

    func toggleFullscreen()
    func enterFullscreen()
    func exitFullscreen()
}

// MARK: - Convenience

public extension VideoPlaying {
    /// Seeks honouring the ``seekCoordinator`` (equivalent to `seek(to:force:false)`).
    func seek(to time: TimeInterval) { seek(to: time, force: false) }
}
