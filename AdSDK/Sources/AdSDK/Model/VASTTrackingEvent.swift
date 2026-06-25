//
//  VASTTrackingEvent.swift
//  AdSDK
//
//  The standard VAST linear tracking events. Each maps to one or more `<Tracking>`
//  URLs in the VAST document that must be pinged when the corresponding playback
//  milestone happens (quartiles, mute, skip, etc.). Kept as a value type so the
//  parser, tracker, and tests can all share one vocabulary.
//

import Foundation

/// A VAST `<Tracking event="...">` kind. `progress` carries the time offset at
/// which it must fire; `other` preserves any non-standard event name verbatim.
public enum VASTTrackingEvent: Equatable, Hashable, Sendable {
    case creativeView
    case start
    case firstQuartile
    case midpoint
    case thirdQuartile
    case complete
    case mute
    case unmute
    case pause
    case resume
    case rewind
    case skip
    case closeLinear
    case fullscreen
    case exitFullscreen
    case acceptInvitation
    case progress(offset: TimeInterval)
    case other(String)

    /// Builds an event from a VAST `event` attribute plus an optional `offset`
    /// attribute (used by `progress`).
    public init(name: String, offset: TimeInterval? = nil) {
        switch name {
        case "creativeView":     self = .creativeView
        case "start":            self = .start
        case "firstQuartile":    self = .firstQuartile
        case "midpoint":         self = .midpoint
        case "thirdQuartile":    self = .thirdQuartile
        case "complete":         self = .complete
        case "mute":             self = .mute
        case "unmute":           self = .unmute
        case "pause":            self = .pause
        case "resume":           self = .resume
        case "rewind":           self = .rewind
        case "skip":             self = .skip
        case "closeLinear", "close": self = .closeLinear
        case "fullscreen":       self = .fullscreen
        case "exitFullscreen":   self = .exitFullscreen
        case "acceptInvitation", "acceptInvitationLinear": self = .acceptInvitation
        case "progress":         self = .progress(offset: offset ?? 0)
        default:                 self = .other(name)
        }
    }

    /// The canonical VAST event name.
    public var rawName: String {
        switch self {
        case .creativeView:    return "creativeView"
        case .start:           return "start"
        case .firstQuartile:   return "firstQuartile"
        case .midpoint:        return "midpoint"
        case .thirdQuartile:   return "thirdQuartile"
        case .complete:        return "complete"
        case .mute:            return "mute"
        case .unmute:          return "unmute"
        case .pause:           return "pause"
        case .resume:          return "resume"
        case .rewind:          return "rewind"
        case .skip:            return "skip"
        case .closeLinear:     return "closeLinear"
        case .fullscreen:      return "fullscreen"
        case .exitFullscreen:  return "exitFullscreen"
        case .acceptInvitation:return "acceptInvitation"
        case .progress:        return "progress"
        case .other(let name): return name
        }
    }
}
