//
//  AdSchedule.swift
//  AdSDK
//
//  Turns a parsed ``VMAP`` plus the content duration and the viewer's ``AdTier``
//  into a concrete, mutable timeline of mid-roll breaks with watched/unwatched
//  state. This is the single source of truth the runtime consults to decide when
//  a break is due and which breaks a seek crosses. Pure (no UIKit/AVFoundation).
//

import Foundation

/// Lifecycle of a single break.
public enum AdBreakState: Sendable, Equatable {
    case unwatched
    case watched
    /// Consumed without playing (e.g. seeked past under `.allowed` policy).
    case skipped
}

/// A VMAP break resolved to an absolute time, with play state.
public struct ScheduledAdBreak: Identifiable, Sendable {
    public let id: String
    public let scheduledTime: TimeInterval
    public let source: AdSource
    /// Per-tier cap on how many ads of this break may play (`nil` = unlimited).
    public let maxAds: Int?
    public var state: AdBreakState

    public var isUnwatched: Bool { state == .unwatched }
}

public final class AdSchedule {

    public private(set) var breaks: [ScheduledAdBreak]
    public let contentDuration: TimeInterval

    /// Builds a mid-roll-only schedule from `vmap`, resolving offsets against
    /// `contentDuration` and applying the `tier` (drops/caps breaks). Breaks are
    /// sorted ascending by time.
    public init(vmap: VMAP, contentDuration: TimeInterval, tier: AdTier) {
        self.contentDuration = contentDuration

        guard tier.playsAds, contentDuration.isFinite, contentDuration > 0 else {
            self.breaks = []
            return
        }

        var resolved: [ScheduledAdBreak] = []
        for (index, adBreak) in vmap.adBreaks.enumerated() where adBreak.isMidRoll {
            guard let time = adBreak.timeOffset.resolved(contentDuration: contentDuration),
                  time > 0, time < contentDuration else { continue }
            resolved.append(ScheduledAdBreak(
                id: adBreak.breakId ?? "break_\(index)",
                scheduledTime: time,
                source: adBreak.adSource,
                maxAds: tier.maxAdsPerBreak,
                state: .unwatched))
        }

        resolved.sort { $0.scheduledTime < $1.scheduledTime }

        if let maxBreaks = tier.maxBreaks, resolved.count > maxBreaks {
            resolved = Array(resolved.prefix(maxBreaks))
        }
        self.breaks = resolved
    }

    // MARK: - Queries

    /// Lightweight cues for the ``AdSeekResolver``.
    public func cues() -> [AdSeekResolver.Cue] {
        breaks.map { AdSeekResolver.Cue(id: $0.id, time: $0.scheduledTime, isUnwatched: $0.isUnwatched) }
    }

    public func adBreak(id: String) -> ScheduledAdBreak? {
        breaks.first { $0.id == id }
    }

    /// The first unwatched break whose time has been reached at `time` (within
    /// `tolerance`). Used to trigger a mid-roll during normal playback.
    public func dueBreak(at time: TimeInterval, tolerance: TimeInterval = 0.75) -> ScheduledAdBreak? {
        breaks.first { $0.isUnwatched && time + tolerance >= $0.scheduledTime && time <= $0.scheduledTime + 30 }
    }

    /// Unwatched breaks strictly within `(from, to]`, ascending — the breaks a
    /// forward seek crosses.
    public func unwatchedBreaks(crossing from: TimeInterval, to: TimeInterval) -> [ScheduledAdBreak] {
        guard to > from else { return [] }
        return breaks.filter { $0.isUnwatched && $0.scheduledTime > from && $0.scheduledTime <= to }
            .sorted { $0.scheduledTime < $1.scheduledTime }
    }

    // MARK: - Mutation

    public func setState(_ state: AdBreakState, forID id: String) {
        guard let index = breaks.firstIndex(where: { $0.id == id }) else { return }
        breaks[index].state = state
    }

    public func markWatched(id: String) { setState(.watched, forID: id) }
    public func markSkipped(id: String) { setState(.skipped, forID: id) }

    /// Marks every unwatched break in `(from, to]` as skipped (used for the
    /// `.allowed` seek policy).
    public func skipUnwatchedBreaks(crossing from: TimeInterval, to: TimeInterval) {
        for adBreak in unwatchedBreaks(crossing: from, to: to) {
            setState(.skipped, forID: adBreak.id)
        }
    }
}
