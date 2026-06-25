//
//  VideoPlayerAdContentAdapter.swift
//  AnimeApp
//
//  The single bridge between PlayerSDK and AdSDK. AdSDK is decoupled from any
//  concrete player via its `AdContentPlayer` abstraction; this adapter conforms
//  `PlayerSDK.VideoPlayerView` to it and translates the player's delegate / seek-
//  coordinator callbacks into the `AdContentPlayerObserver` the coordinator
//  expects. A `passthroughDelegate` lets the host keep observing raw player events.
//

import UIKit
import AVFoundation
import PlayerSDK
import AdSDK

@MainActor
final class VideoPlayerAdContentAdapter: AdContentPlayer {

    private let player: VideoPlayerView
    private let accentColor: UIColor

    weak var adObserver: AdContentPlayerObserver?

    /// Optional pass-through so the host can still observe raw player events
    /// (logging, UI) without being the player's direct delegate.
    weak var passthroughDelegate: VideoPlayerDelegate?

    init(player: VideoPlayerView, accentColor: UIColor) {
        self.player = player
        self.accentColor = accentColor
        player.delegate = self
        player.seekCoordinator = self
    }

    // MARK: - AdContentPlayer

    var adContentView: UIView { player }
    var currentTime: TimeInterval { player.currentTime }
    var contentDuration: TimeInterval { player.duration }
    var currentPlayerItem: AVPlayerItem? { player.currentItem }

    func loadContent(url: URL, title: String?) {
        player.load(VideoPlayerConfiguration(
            url: url, title: title, autoPlay: true, accentColor: accentColor))
    }

    func playContent() { player.play() }
    func pauseContent() { player.pause() }

    func setAdCueMarkers(_ times: [TimeInterval]) { player.setCueMarkers(times) }

    /// Forced seek bypasses the seek coordinator so the ad flow can resume content
    /// at the viewer's destination after a break.
    func seekContent(to time: TimeInterval) { player.seek(to: time, force: true) }
}

// MARK: - VideoPlayerSeekCoordinator (seek interception)

extension VideoPlayerAdContentAdapter: VideoPlayerSeekCoordinator {
    func videoPlayer(_ player: VideoPlayerView, shouldPerformSeekTo target: TimeInterval) -> Bool {
        adObserver?.contentPlayer(shouldSeekTo: target) ?? true
    }
}

// MARK: - VideoPlayerDelegate (forward to observer + passthrough)

extension VideoPlayerAdContentAdapter: VideoPlayerDelegate {

    func videoPlayer(_ player: VideoPlayerView, didBecomeReadyWithDuration duration: TimeInterval) {
        adObserver?.contentPlayerDidBecomeReady(duration: duration)
        passthroughDelegate?.videoPlayer(player, didBecomeReadyWithDuration: duration)
    }

    func videoPlayer(_ player: VideoPlayerView, didProgressTo current: TimeInterval, duration: TimeInterval) {
        adObserver?.contentPlayerDidProgress(to: current, duration: duration)
        passthroughDelegate?.videoPlayer(player, didProgressTo: current, duration: duration)
    }

    func videoPlayerDidPlay(_ player: VideoPlayerView) {
        adObserver?.contentPlayerDidStartPlaying()
        passthroughDelegate?.videoPlayerDidPlay(player)
    }

    func videoPlayerDidPause(_ player: VideoPlayerView) {
        passthroughDelegate?.videoPlayerDidPause(player)
    }

    func videoPlayerDidFinish(_ player: VideoPlayerView) {
        adObserver?.contentPlayerDidFinish()
        passthroughDelegate?.videoPlayerDidFinish(player)
    }

    func videoPlayer(_ player: VideoPlayerView, didChangeState state: VideoPlayerState) {
        passthroughDelegate?.videoPlayer(player, didChangeState: state)
    }

    func videoPlayer(_ player: VideoPlayerView, didFailWithError error: Error) {
        passthroughDelegate?.videoPlayer(player, didFailWithError: error)
    }

    func videoPlayer(_ player: VideoPlayerView, didSeekTo time: TimeInterval) {
        passthroughDelegate?.videoPlayer(player, didSeekTo: time)
    }
}
