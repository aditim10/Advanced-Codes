//
//  AdManager.swift
//  AdSDK
//
//  The decision "brain". It owns the mutable ``AdSchedule`` and the seek policy,
//  and answers two questions for the playback coordinator:
//    1. "Is a mid-roll due at this content time?" (normal-playback trigger)
//    2. "What should happen for this seek?" (snap-to-ad / snap-back vs allow)
//  It holds no AVFoundation/UIKit, so it is fully unit-testable.
//

import Foundation

public final class AdManager {

    public let schedule: AdSchedule
    public let seekPolicy: SeekAdPolicy

    public init(schedule: AdSchedule, seekPolicy: SeekAdPolicy) {
        self.schedule = schedule
        self.seekPolicy = seekPolicy
    }

    /// `true` when at least one mid-roll break has not yet played.
    public var hasUnwatchedBreaks: Bool {
        schedule.breaks.contains { $0.isUnwatched }
    }

    /// The break that should start now given linear playback reached `time`.
    public func dueBreak(at time: TimeInterval) -> ScheduledAdBreak? {
        schedule.dueBreak(at: time)
    }

    public func adBreak(id: String) -> ScheduledAdBreak? {
        schedule.adBreak(id: id)
    }

    /// Resolves a seek. Under `.allowed`, a forward seek that crosses unwatched
    /// breaks marks them skipped (consumed) and the seek is honoured. Under
    /// `.redirect`, the first crossed unwatched break is returned for playback,
    /// carrying the original destination to resume at afterwards.
    public func resolveSeek(from current: TimeInterval, to requested: TimeInterval) -> AdSeekResolver.Decision {
        let decision = AdSeekResolver.resolve(
            from: current, to: requested, cues: schedule.cues(), policy: seekPolicy)

        if case .seek = decision, seekPolicy == .allowed, requested > current {
            schedule.skipUnwatchedBreaks(crossing: current, to: requested)
        }
        return decision
    }

    /// Marks a break watched once its ads have played (or were skipped by the user).
    public func markBreakWatched(id: String) {
        schedule.markWatched(id: id)
    }
}
