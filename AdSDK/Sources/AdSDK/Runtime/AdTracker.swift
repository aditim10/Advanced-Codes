//
//  AdTracker.swift
//  AdSDK
//
//  Fires VAST tracking beacons over the network. Beacons are fire-and-forget GET
//  requests; we don't care about the response, only that the impression/quartile/
//  click/skip pixel is hit. Quartile crossing is computed from ad progress so the
//  caller only needs to feed it the current time.
//

import Foundation

/// Fires VAST tracking beacons. Abstracted so the ad overlay depends on a
/// behaviour, not a concrete networking type (swap a no-op/spy in tests).
public protocol AdTracking: AnyObject {
    func fire(_ urls: [URL])
    func track(_ event: VASTTrackingEvent, for ad: PlayableAd)
    func impression(for ad: PlayableAd)
    func clickTracking(for ad: PlayableAd)
    func error(for ad: PlayableAd)
    func fireProgress(for ad: PlayableAd, previous: TimeInterval, current: TimeInterval)
}

public final class AdTracker: AdTracking {

    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    /// Fires every URL as a fire-and-forget GET.
    public func fire(_ urls: [URL]) {
        for url in urls {
            session.dataTask(with: url).resume()
        }
    }

    /// Fires all beacons registered for a standard tracking `event`.
    public func track(_ event: VASTTrackingEvent, for ad: PlayableAd) {
        fire(ad.urls(for: event))
    }

    /// Fires the ad's impression beacons (call once, when the ad starts).
    public func impression(for ad: PlayableAd) {
        fire(ad.impressions)
    }

    /// Fires click-tracking beacons (call alongside opening the clickThrough).
    public func clickTracking(for ad: PlayableAd) {
        fire(ad.clickTracking)
    }

    /// Fires the ad's error beacons.
    public func error(for ad: PlayableAd) {
        fire(ad.errors)
    }

    /// Fires any `progress` beacons whose offset falls in `(previous, current]`.
    public func fireProgress(for ad: PlayableAd, previous: TimeInterval, current: TimeInterval) {
        let due = ad.progressTracking
            .filter { $0.offset > previous && $0.offset <= current }
            .map(\.url)
        fire(due)
    }
}
