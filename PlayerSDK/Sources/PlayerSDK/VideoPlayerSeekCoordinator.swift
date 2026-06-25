//
//  VideoPlayerSeekCoordinator.swift
//  PlayerSDK
//
//  An optional hook that lets an external object (e.g. an ad coordinator) veto and
//  take over a seek before it happens. When set, `VideoPlayerView.seek(to:)` asks
//  the coordinator first; returning `false` aborts the direct seek so the
//  coordinator can run its own flow (play an ad break, etc.) and then re-issue the
//  seek with `force: true`.
//

import Foundation

public protocol VideoPlayerSeekCoordinator: AnyObject {
    /// Return `true` to allow the player to seek to `target` directly, or `false`
    /// to take over (the coordinator is then responsible for completing the seek,
    /// typically via `seek(to:force:)`).
    func videoPlayer(_ player: VideoPlayerView, shouldPerformSeekTo target: TimeInterval) -> Bool
}
