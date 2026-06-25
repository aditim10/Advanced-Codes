//
//  SeekAdPolicy.swift
//  AdSDK
//
//  What happens when the viewer seeks *across* an unwatched mid-roll cue point:
//  - `.allowed`  the seek is honoured; crossed breaks are marked consumed (skipped)
//  - `.redirect` the player snaps to the unwatched break, plays it, then snaps back
//                to the viewer's intended destination
//

import Foundation

public enum SeekAdPolicy: String, CaseIterable, Sendable {
    case allowed
    case redirect

    public var displayName: String {
        switch self {
        case .allowed:  return "Seek allowed"
        case .redirect: return "Seek redirects to ad"
        }
    }
}
