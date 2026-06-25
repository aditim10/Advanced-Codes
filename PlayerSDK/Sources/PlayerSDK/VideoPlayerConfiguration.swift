//
//  VideoPlayerConfiguration.swift
//  PlayerSDK
//
//  The single value the client hands the player to describe *what* to play and
//  *how* it should behave/look. Kept as a plain value type so it's trivial to
//  build, copy, and unit-test.
//

import UIKit

/// Everything the player needs to start: the media URL plus behaviour/appearance
/// options. Build one and pass it to `VideoPlayerView.load(_:)` (or any
/// `VideoPlaying` conformer).
public struct VideoPlayerConfiguration {

    /// The media URL.
    public let url: URL

    /// An optional title shown in the player chrome (e.g. the anime name).
    public var title: String?

    /// Start playback automatically once the item is ready. Defaults to `true`.
    public var autoPlay: Bool

    /// Begin muted (useful for autoplaying previews). Defaults to `false`.
    public var startsMuted: Bool

    /// Restart from the beginning when playback reaches the end. Defaults to `false`.
    public var loops: Bool

    /// Number of seconds the skip-back / skip-forward controls jump. Defaults to `10`.
    public var skipInterval: TimeInterval

    /// Tint used for the controls (buttons, scrubber). Defaults to system purple.
    public var accentColor: UIColor

    public init(
        url: URL,
        title: String? = nil,
        autoPlay: Bool = true,
        startsMuted: Bool = false,
        loops: Bool = false,
        skipInterval: TimeInterval = 10,
        accentColor: UIColor = .systemPurple
    ) {
        self.url = url
        self.title = title
        self.autoPlay = autoPlay
        self.startsMuted = startsMuted
        self.loops = loops
        self.skipInterval = skipInterval
        self.accentColor = accentColor
    }
}
