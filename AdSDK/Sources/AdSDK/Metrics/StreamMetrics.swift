//
//  StreamMetrics.swift
//  AdSDK
//
//  A snapshot of HLS playback quality, modelled on the metrics an hls.js-style
//  dashboard surfaces (bitrate, level switches, rebuffering, dropped frames,
//  bandwidth, errors). Derived from `AVPlayerItem`'s access/error logs by
//  ``StreamMetricsCollector`` and forwarded to the host via `AdSDKLogger`.
//

import Foundation

public struct StreamMetrics: Sendable, Equatable {

    /// Whether this snapshot is for ad media or the main content stream.
    public enum Kind: String, Sendable {
        case content
        case ad
    }

    public var kind: Kind
    /// Bitrate the server declared for the current rendition (bps).
    public var indicatedBitrate: Double
    /// Throughput actually observed downloading segments (bps).
    public var observedBitrate: Double
    /// Average video track bitrate played back (bps).
    public var averageVideoBitrate: Double
    /// Average audio track bitrate played back (bps).
    public var averageAudioBitrate: Double
    /// Rebuffering events (stalls).
    public var stallCount: Int
    /// Video frames dropped (a smoothness indicator).
    public var droppedVideoFrames: Int
    /// Total bytes transferred for this item.
    public var bytesTransferred: Int64
    /// Number of media (segment/playlist) requests.
    public var mediaRequests: Int
    /// Rendition switches (ABR level changes) during playback.
    public var switchCount: Int
    /// Playback/network errors logged for this item.
    public var errorCount: Int
    /// Time from load to first frame (seconds), measured by the coordinator.
    public var startupTime: TimeInterval
    /// Total wall-clock duration watched (seconds).
    public var durationWatched: TimeInterval

    public init(kind: Kind = .content,
                indicatedBitrate: Double = 0,
                observedBitrate: Double = 0,
                averageVideoBitrate: Double = 0,
                averageAudioBitrate: Double = 0,
                stallCount: Int = 0,
                droppedVideoFrames: Int = 0,
                bytesTransferred: Int64 = 0,
                mediaRequests: Int = 0,
                switchCount: Int = 0,
                errorCount: Int = 0,
                startupTime: TimeInterval = 0,
                durationWatched: TimeInterval = 0) {
        self.kind = kind
        self.indicatedBitrate = indicatedBitrate
        self.observedBitrate = observedBitrate
        self.averageVideoBitrate = averageVideoBitrate
        self.averageAudioBitrate = averageAudioBitrate
        self.stallCount = stallCount
        self.droppedVideoFrames = droppedVideoFrames
        self.bytesTransferred = bytesTransferred
        self.mediaRequests = mediaRequests
        self.switchCount = switchCount
        self.errorCount = errorCount
        self.startupTime = startupTime
        self.durationWatched = durationWatched
    }

    /// Flattened key/value form convenient for analytics parameters.
    public var dictionary: [String: Any] {
        [
            "kind": kind.rawValue,
            "indicated_bitrate": Int(indicatedBitrate),
            "observed_bitrate": Int(observedBitrate),
            "avg_video_bitrate": Int(averageVideoBitrate),
            "avg_audio_bitrate": Int(averageAudioBitrate),
            "stalls": stallCount,
            "dropped_frames": droppedVideoFrames,
            "bytes_transferred": bytesTransferred,
            "media_requests": mediaRequests,
            "switches": switchCount,
            "errors": errorCount,
            "startup_time": startupTime,
            "duration_watched": durationWatched,
        ]
    }
}
