//
//  PlaybackAudioSession.swift
//  PlayerSDK
//
//  A seam over `AVAudioSession` so the player isn't hard-wired to a global
//  singleton. The default activates movie playback (audible even with the mute
//  switch on); tests or hosts can inject a no-op or a custom configuration.
//

import AVFoundation

public protocol PlaybackAudioSession {
    /// Configures + activates the audio session for video playback.
    func activatePlayback()
}

/// Default implementation backed by the shared `AVAudioSession`.
public struct AVPlaybackAudioSession: PlaybackAudioSession {

    public init() {}

    public func activatePlayback() {
        // `setActive` can briefly block, so do it off the main thread.
        DispatchQueue.global(qos: .userInitiated).async {
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            try? AVAudioSession.sharedInstance().setActive(true)
        }
    }
}
