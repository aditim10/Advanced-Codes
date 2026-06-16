//
//  VideoTime.swift
//  PlayerSDK
//
//  Pure, side-effect-free helpers for time math and formatting. Kept separate so
//  the skip/clamp logic can be unit-tested without a real `AVPlayer`.
//

import Foundation

public enum VideoTime {

    /// Clamps `time` into the valid `0...duration` range. Guards against NaN and
    /// negative/overflowing seeks (e.g. skipping past the end).
    public static func clamp(_ time: TimeInterval, duration: TimeInterval) -> TimeInterval {
        guard duration.isFinite, duration > 0 else { return 0 }
        if time.isNaN { return 0 }
        return Swift.min(Swift.max(time, 0), duration)
    }

    /// The target time after applying a relative `offset` (e.g. +10 / −10s),
    /// clamped to the item's bounds.
    public static func target(from current: TimeInterval, offset: TimeInterval, duration: TimeInterval) -> TimeInterval {
        clamp(current + offset, duration: duration)
    }

    /// `0...1` progress for a scrubber. Returns 0 when the duration is unknown.
    public static func progress(current: TimeInterval, duration: TimeInterval) -> Float {
        guard duration.isFinite, duration > 0 else { return 0 }
        return Float(clamp(current, duration: duration) / duration)
    }

    /// Formats seconds as `m:ss` (or `h:mm:ss` for long media). Used by the labels.
    public static func formatted(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let total = Int(seconds.rounded())
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }
}
