//
//  StreamMetricsCollector.swift
//  AdSDK
//
//  Reads `AVPlayerItem.accessLog()` / `errorLog()` and aggregates them into a
//  ``StreamMetrics`` snapshot. The access log contains one event per server /
//  rendition session, so cumulative counters are summed and the "current" rates
//  come from the latest event. Negative sentinel values (-1 = unavailable) are
//  clamped to zero.
//

import Foundation
import AVFoundation

/// Produces a ``StreamMetrics`` snapshot for a player item. Behind a protocol so
/// the coordinator can be given a stub in tests instead of a live AV item.
public protocol StreamMetricsCollecting: AnyObject {
    func snapshot(for item: AVPlayerItem?, kind: StreamMetrics.Kind, startupTime: TimeInterval) -> StreamMetrics
}

public final class StreamMetricsCollector: StreamMetricsCollecting {

    public init() {}

    /// Builds a snapshot for `item`. `startupTime` (time-to-first-frame) is
    /// measured by the coordinator and passed in, since the access log doesn't
    /// expose it directly.
    public func snapshot(for item: AVPlayerItem?,
                         kind: StreamMetrics.Kind = .content,
                         startupTime: TimeInterval = 0) -> StreamMetrics {
        var metrics = StreamMetrics(kind: kind, startupTime: startupTime)
        guard let item else { return metrics }

        if let accessLog = item.accessLog(), !accessLog.events.isEmpty {
            let events = accessLog.events

            metrics.switchCount = max(0, events.count - 1)
            for event in events {
                metrics.stallCount        += max(0, event.numberOfStalls)
                metrics.droppedVideoFrames += max(0, event.numberOfDroppedVideoFrames)
                metrics.mediaRequests     += max(0, event.numberOfMediaRequests)
                if event.numberOfBytesTransferred > 0 {
                    metrics.bytesTransferred += event.numberOfBytesTransferred
                }
                if event.durationWatched > 0 {
                    metrics.durationWatched += event.durationWatched
                }
            }

            if let latest = events.last {
                metrics.indicatedBitrate = max(0, latest.indicatedBitrate)
                metrics.observedBitrate = max(0, latest.observedBitrate)
                metrics.averageVideoBitrate = max(0, latest.averageVideoBitrate)
                metrics.averageAudioBitrate = max(0, latest.averageAudioBitrate)
            }
        }

        if let errorLog = item.errorLog() {
            metrics.errorCount = errorLog.events.count
        }

        return metrics
    }
}
