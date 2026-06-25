//
//  PlayableAd.swift
//  AdSDK
//
//  The runtime, render-ready form of a single linear ad: one media URL plus the
//  tracking/click metadata needed while it plays. Built from a fully-resolved
//  (inline) ``VAST`` document, picking the best media file per ad and applying the
//  tier's per-break ad cap.
//

import Foundation

public struct PlayableAd: Identifiable, Sendable {
    public let id: String
    public let title: String?
    public let mediaURL: URL
    public let duration: TimeInterval?
    public let skipOffset: TimeInterval?
    public let impressions: [URL]
    public let errors: [URL]
    public let trackingEvents: [TrackingEntry]
    public let clickThrough: URL?
    public let clickTracking: [URL]

    public init(id: String,
                title: String?,
                mediaURL: URL,
                duration: TimeInterval?,
                skipOffset: TimeInterval?,
                impressions: [URL],
                errors: [URL],
                trackingEvents: [TrackingEntry],
                clickThrough: URL?,
                clickTracking: [URL]) {
        self.id = id
        self.title = title
        self.mediaURL = mediaURL
        self.duration = duration
        self.skipOffset = skipOffset
        self.impressions = impressions
        self.errors = errors
        self.trackingEvents = trackingEvents
        self.clickThrough = clickThrough
        self.clickTracking = clickTracking
    }

    /// `true` if the ad can be skipped at some point.
    public var isSkippable: Bool { skipOffset != nil }

    /// Tracking URLs registered for `event`.
    public func urls(for event: VASTTrackingEvent) -> [URL] {
        trackingEvents.filter { $0.event == event }.map(\.url)
    }

    /// All `progress` tracking entries paired with their fire offsets.
    public var progressTracking: [(offset: TimeInterval, url: URL)] {
        trackingEvents.compactMap { entry in
            if case .progress(let offset) = entry.event { return (offset, entry.url) }
            return nil
        }
    }

    // MARK: - Building

    /// Builds the playable ad pod from a resolved VAST (wrappers already resolved
    /// to inline), choosing each ad's preferred media file. `maxAds` caps the pod
    /// (used by ad-lite); `nil` keeps all.
    public static func pod(from vast: VAST, maxAds: Int?) -> [PlayableAd] {
        var ads: [PlayableAd] = []
        for (index, vastAd) in vast.orderedAds.enumerated() {
            guard let inLine = vastAd.inLine,
                  let linear = inLine.linear,
                  let media = linear.preferredMediaFile else { continue }
            ads.append(PlayableAd(
                id: vastAd.id ?? "ad_\(index)",
                title: inLine.adTitle,
                mediaURL: media.url,
                duration: linear.duration,
                skipOffset: linear.skipOffset,
                impressions: inLine.impressions,
                errors: inLine.errors,
                trackingEvents: linear.trackingEvents,
                clickThrough: linear.videoClicks?.clickThrough,
                clickTracking: linear.videoClicks?.clickTracking ?? []))
        }
        if let maxAds, ads.count > maxAds {
            ads = Array(ads.prefix(maxAds))
        }
        return ads
    }
}
