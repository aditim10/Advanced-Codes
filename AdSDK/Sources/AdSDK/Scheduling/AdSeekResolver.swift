//
//  AdSeekResolver.swift
//  AdSDK
//
//  The pure heart of the "snap to unwatched ad break, then snap back to the
//  viewer's destination" behaviour. Given where the playhead is, where the viewer
//  asked to go, the cue points, and the policy, it returns a single decision.
//
//  It is intentionally stateless and iterative: when it returns `.playBreak`, the
//  caller plays that break, marks it watched, and asks again (with the playhead
//  now at the break) until no crossed unwatched break remains and the final
//  `.seek(to:)` lands the viewer at their original destination.
//

import Foundation

public enum AdSeekResolver {

    /// A minimal view of a scheduled break for seek math.
    public struct Cue: Equatable, Sendable {
        public let id: String
        public let time: TimeInterval
        public let isUnwatched: Bool

        public init(id: String, time: TimeInterval, isUnwatched: Bool) {
            self.id = id
            self.time = time
            self.isUnwatched = isUnwatched
        }
    }

    /// What the player should do for a seek request.
    public enum Decision: Equatable, Sendable {
        /// Honour the seek immediately.
        case seek(to: TimeInterval)
        /// Play `id`'s ad break first, then resume at `resumeAt` (the original target).
        case playBreak(id: String, resumeAt: TimeInterval)
    }

    /// Resolves a seek from `current` to `requested`.
    ///
    /// - `.allowed` policy, or a backward/no-op seek: always `.seek(to:)`.
    /// - `.redirect` policy on a forward seek that crosses one or more unwatched
    ///   cues: `.playBreak` for the *first* crossed unwatched cue, carrying the
    ///   original `requested` time as `resumeAt`.
    public static func resolve(from current: TimeInterval,
                               to requested: TimeInterval,
                               cues: [Cue],
                               policy: SeekAdPolicy) -> Decision {
        guard policy == .redirect, requested > current else {
            return .seek(to: requested)
        }
        let crossed = cues
            .filter { $0.isUnwatched && $0.time > current && $0.time <= requested }
            .sorted { $0.time < $1.time }

        guard let first = crossed.first else { return .seek(to: requested) }
        return .playBreak(id: first.id, resumeAt: requested)
    }
}
