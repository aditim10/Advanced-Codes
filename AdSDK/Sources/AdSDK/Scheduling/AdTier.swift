//
//  AdTier.swift
//  AdSDK
//
//  The viewer's advertising entitlement. Drives how many breaks/ads actually play:
//  - `.adFree`      no ads at all
//  - `.adLite`      a reduced experience: only the first mid-roll, one ad per break
//  - `.adSupported` the full schedule
//

import Foundation

public enum AdTier: String, CaseIterable, Sendable {
    case adFree
    case adLite
    case adSupported

    /// Human-readable label (the host app may localise this itself).
    public var displayName: String {
        switch self {
        case .adFree:       return "Ad-free"
        case .adLite:       return "Ad-lite"
        case .adSupported:  return "Ad-supported"
        }
    }

    /// Whether any ads play for this tier.
    public var playsAds: Bool { self != .adFree }

    /// Maximum number of mid-roll breaks to keep (`nil` = unlimited).
    public var maxBreaks: Int? {
        switch self {
        case .adFree:       return 0
        case .adLite:       return 1
        case .adSupported:  return nil
        }
    }

    /// Maximum ads played per break / ad-pod (`nil` = unlimited).
    public var maxAdsPerBreak: Int? {
        switch self {
        case .adFree:       return 0
        case .adLite:       return 1
        case .adSupported:  return nil
        }
    }
}
