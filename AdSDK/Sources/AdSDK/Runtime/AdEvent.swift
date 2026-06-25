//
//  AdEvent.swift
//  AdSDK
//
//  The host-facing event stream the SDK emits during ad playback. The app bridges
//  these into its own analytics (see `AdSDKLogger`). Distinct from VAST tracking
//  beacons (which fire over the network via `AdTracker`).
//

import Foundation

/// The four standard linear-ad quartile milestones plus start.
public enum AdQuartile: String, Sendable {
    case start
    case firstQuartile
    case midpoint
    case thirdQuartile
    case complete
}

public enum AdEvent: Sendable {
    /// An ad break is about to play `adCount` ads.
    case breakStarted(breakID: String, adCount: Int)
    /// A specific ad started (`index` is 0-based within the break of `count`).
    case adStarted(adID: String, title: String?, index: Int, count: Int)
    /// Periodic progress within the current ad.
    case adProgress(adID: String, time: TimeInterval, duration: TimeInterval)
    /// A quartile milestone was reached.
    case quartile(adID: String, quartile: AdQuartile)
    /// The viewer skipped the ad.
    case adSkipped(adID: String)
    /// The viewer tapped the ad (Learn More / clickthrough).
    case adClicked(adID: String, url: URL)
    /// The ad finished playing to completion.
    case adCompleted(adID: String)
    /// The whole break finished (all ads done/skipped).
    case breakCompleted(breakID: String)
    /// An ad failed to load/play, or the break could not be resolved.
    case adError(adID: String?, message: String)
}
