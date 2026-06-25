//
//  VMAPModels.swift
//  AdSDK
//
//  Value types for a VMAP document — the "playlist of ad breaks" that says *when*
//  ads should play (time offsets) and *where* the ads come from (inline VAST or a
//  remote ad-tag URI). AdSDK only schedules mid-rolls, but the model supports the
//  full offset vocabulary so the parser stays spec-faithful.
//

import Foundation

/// A parsed VMAP document: an ordered list of ad breaks.
public struct VMAP: Equatable, Sendable {
    public var version: String
    public var adBreaks: [AdBreak]

    public init(version: String = "1.0", adBreaks: [AdBreak] = []) {
        self.version = version
        self.adBreaks = adBreaks
    }
}

/// A single `<vmap:AdBreak>`: when to play, what type, and the ad source.
public struct AdBreak: Equatable, Sendable {
    public var timeOffset: TimeOffset
    public var breakTypes: [String]
    public var breakId: String?
    public var adSource: AdSource

    public init(timeOffset: TimeOffset,
                breakTypes: [String] = ["linear"],
                breakId: String? = nil,
                adSource: AdSource) {
        self.timeOffset = timeOffset
        self.breakTypes = breakTypes
        self.breakId = breakId
        self.adSource = adSource
    }

    /// `true` for a mid-roll (a positive time/percentage offset, not start/end).
    public var isMidRoll: Bool {
        switch timeOffset {
        case .seconds(let s):    return s > 0
        case .percentage(let p): return p > 0 && p < 1
        case .position:          return true
        case .start, .end:       return false
        }
    }
}

/// Where the ad for a break lives.
public enum AdSource: Equatable, Sendable {
    /// Inline VAST embedded directly in the VMAP (`<vmap:VASTAdData>`).
    case vast(VAST)
    /// A remote VAST tag to fetch (`<vmap:AdTagURI>`).
    case adTagURI(URL)
}

/// A VMAP `timeOffset` value.
public enum TimeOffset: Equatable, Sendable {
    case start
    case end
    /// Absolute time in seconds (parsed from `HH:MM:SS(.mmm)`).
    case seconds(TimeInterval)
    /// Fraction of the content duration in `0...1` (parsed from `NN%`).
    case percentage(Double)
    /// Ordinal position `#N` (1-based).
    case position(Int)

    /// Parses a VMAP `timeOffset` attribute. Returns `nil` if unrecognised.
    public static func parse(_ raw: String) -> TimeOffset? {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        switch value.lowercased() {
        case "start": return .start
        case "end":   return .end
        default: break
        }
        if value.hasSuffix("%"), let pct = Double(value.dropLast()) {
            return .percentage(pct / 100.0)
        }
        if value.hasPrefix("#"), let pos = Int(value.dropFirst()) {
            return .position(pos)
        }
        if let seconds = Self.parseClock(value) {
            return .seconds(seconds)
        }
        return nil
    }

    /// Resolves the offset to an absolute time against `contentDuration`. Returns
    /// `nil` for ordinal `position` offsets, which aren't time-based.
    public func resolved(contentDuration: TimeInterval) -> TimeInterval? {
        switch self {
        case .start:             return 0
        case .end:               return contentDuration
        case .seconds(let s):    return s
        case .percentage(let p): return p * contentDuration
        case .position:          return nil
        }
    }

    /// Parses `HH:MM:SS(.mmm)` (or `MM:SS`) into seconds.
    private static func parseClock(_ value: String) -> TimeInterval? {
        let parts = value.split(separator: ":")
        guard !parts.isEmpty, parts.count <= 3 else { return nil }
        var seconds: TimeInterval = 0
        for part in parts {
            guard let component = Double(part) else { return nil }
            seconds = seconds * 60 + component
        }
        return seconds
    }
}
