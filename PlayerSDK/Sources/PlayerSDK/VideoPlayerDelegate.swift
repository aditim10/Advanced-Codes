//
//  VideoPlayerDelegate.swift
//  PlayerSDK
//
//  The callback surface the client implements to observe the player. Every method
//  has a default no-op implementation (see the protocol extension), so clients
//  only override the events they care about.
//

import Foundation

/// The lifecycle/state of the player, surfaced to the delegate.
public enum VideoPlayerState: Equatable {
    case idle               // nothing loaded yet
    case loading            // an item was set; waiting for it to become playable
    case readyToPlay        // item is playable
    case playing
    case paused
    case ended              // reached the end of the item
    case failed(String)     // could not load / play; carries a human-readable reason
}

/// Receives all player events. Conform on your view controller (or a coordinator)
/// and set it as `VideoPlayerView.delegate`.
///
/// All methods are optional via the default implementations below.
public protocol VideoPlayerDelegate: AnyObject {

    /// Called for every state transition (the most general callback).
    func videoPlayer(_ player: VideoPlayerView, didChangeState state: VideoPlayerState)

    /// The item became playable; `duration` is the total length in seconds.
    func videoPlayer(_ player: VideoPlayerView, didBecomeReadyWithDuration duration: TimeInterval)

    /// Playback started or resumed.
    func videoPlayerDidPlay(_ player: VideoPlayerView)

    /// Playback paused.
    func videoPlayerDidPause(_ player: VideoPlayerView)

    /// Periodic playback progress (roughly twice a second while playing).
    func videoPlayer(_ player: VideoPlayerView, didProgressTo current: TimeInterval, duration: TimeInterval)

    /// The user (or code) sought to `time` seconds.
    func videoPlayer(_ player: VideoPlayerView, didSeekTo time: TimeInterval)

    /// Volume or mute state changed.
    func videoPlayer(_ player: VideoPlayerView, didChangeVolume volume: Float, isMuted: Bool)

    /// Entered (`true`) or exited (`false`) fullscreen.
    func videoPlayer(_ player: VideoPlayerView, didToggleFullscreen isFullscreen: Bool)

    /// Playback reached the end of the item.
    func videoPlayerDidFinish(_ player: VideoPlayerView)

    /// Loading or playback failed.
    func videoPlayer(_ player: VideoPlayerView, didFailWithError error: Error)
}

// MARK: - Default no-op implementations

public extension VideoPlayerDelegate {
    func videoPlayer(_ player: VideoPlayerView, didChangeState state: VideoPlayerState) {}
    func videoPlayer(_ player: VideoPlayerView, didBecomeReadyWithDuration duration: TimeInterval) {}
    func videoPlayerDidPlay(_ player: VideoPlayerView) {}
    func videoPlayerDidPause(_ player: VideoPlayerView) {}
    func videoPlayer(_ player: VideoPlayerView, didProgressTo current: TimeInterval, duration: TimeInterval) {}
    func videoPlayer(_ player: VideoPlayerView, didSeekTo time: TimeInterval) {}
    func videoPlayer(_ player: VideoPlayerView, didChangeVolume volume: Float, isMuted: Bool) {}
    func videoPlayer(_ player: VideoPlayerView, didToggleFullscreen isFullscreen: Bool) {}
    func videoPlayerDidFinish(_ player: VideoPlayerView) {}
    func videoPlayer(_ player: VideoPlayerView, didFailWithError error: Error) {}
}
