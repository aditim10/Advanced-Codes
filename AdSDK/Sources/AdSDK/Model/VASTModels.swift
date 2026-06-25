//
//  VASTModels.swift
//  AdSDK
//
//  Value types mirroring the VAST document tree we care about for linear video
//  ads: an ad is either an `InLine` (a real creative with media + tracking) or a
//  `Wrapper` (a redirect to another VAST tag, carrying extra tracking that must
//  be merged in once resolved). Everything is `Sendable` so it can cross the
//  concurrency boundary in the wrapper resolver and tests.
//

import Foundation

/// A parsed VAST document.
public struct VAST: Equatable, Sendable {
    public var version: String
    public var ads: [VASTAd]

    public init(version: String = "4.0", ads: [VASTAd] = []) {
        self.version = version
        self.ads = ads
    }

    /// Ads ordered by their `sequence` (ad-pod order), unsequenced ads last.
    public var orderedAds: [VASTAd] {
        ads.enumerated().sorted { lhs, rhs in
            let l = lhs.element.sequence ?? Int.max
            let r = rhs.element.sequence ?? Int.max
            return l == r ? lhs.offset < rhs.offset : l < r
        }.map(\.element)
    }
}

/// A single `<Ad>` — either inline media or a wrapper redirect.
public struct VASTAd: Equatable, Sendable {
    public var id: String?
    public var sequence: Int?
    public var content: Content

    public enum Content: Equatable, Sendable {
        case inLine(InLine)
        case wrapper(Wrapper)
    }

    public init(id: String? = nil, sequence: Int? = nil, content: Content) {
        self.id = id
        self.sequence = sequence
        self.content = content
    }

    public var inLine: InLine? {
        if case .inLine(let value) = content { return value }
        return nil
    }

    public var wrapper: Wrapper? {
        if case .wrapper(let value) = content { return value }
        return nil
    }
}

/// A real ad with playable media.
public struct InLine: Equatable, Sendable {
    public var adSystem: String?
    public var adTitle: String?
    public var impressions: [URL]
    public var errors: [URL]
    public var creatives: [Creative]

    public init(adSystem: String? = nil,
                adTitle: String? = nil,
                impressions: [URL] = [],
                errors: [URL] = [],
                creatives: [Creative] = []) {
        self.adSystem = adSystem
        self.adTitle = adTitle
        self.impressions = impressions
        self.errors = errors
        self.creatives = creatives
    }

    /// The first linear creative (the only kind AdSDK renders).
    public var linear: Linear? { creatives.compactMap(\.linear).first }
}

/// A redirect to another VAST tag, plus tracking that must be carried forward.
public struct Wrapper: Equatable, Sendable {
    public var adSystem: String?
    public var vastAdTagURI: URL
    public var impressions: [URL]
    public var errors: [URL]
    public var creatives: [Creative]
    public var followAdditionalWrappers: Bool
    public var allowMultipleAds: Bool

    public init(adSystem: String? = nil,
                vastAdTagURI: URL,
                impressions: [URL] = [],
                errors: [URL] = [],
                creatives: [Creative] = [],
                followAdditionalWrappers: Bool = true,
                allowMultipleAds: Bool = true) {
        self.adSystem = adSystem
        self.vastAdTagURI = vastAdTagURI
        self.impressions = impressions
        self.errors = errors
        self.creatives = creatives
        self.followAdditionalWrappers = followAdditionalWrappers
        self.allowMultipleAds = allowMultipleAds
    }
}

/// A `<Creative>` — AdSDK only models the `Linear` subtype.
public struct Creative: Equatable, Sendable {
    public var id: String?
    public var sequence: Int?
    public var linear: Linear?

    public init(id: String? = nil, sequence: Int? = nil, linear: Linear? = nil) {
        self.id = id
        self.sequence = sequence
        self.linear = linear
    }
}

/// The linear (in-stream) creative: media, tracking, click info, skip rule.
public struct Linear: Equatable, Sendable {
    public var skipOffset: TimeInterval?
    public var duration: TimeInterval?
    public var mediaFiles: [MediaFile]
    public var trackingEvents: [TrackingEntry]
    public var videoClicks: VideoClicks?

    public init(skipOffset: TimeInterval? = nil,
                duration: TimeInterval? = nil,
                mediaFiles: [MediaFile] = [],
                trackingEvents: [TrackingEntry] = [],
                videoClicks: VideoClicks? = nil) {
        self.skipOffset = skipOffset
        self.duration = duration
        self.mediaFiles = mediaFiles
        self.trackingEvents = trackingEvents
        self.videoClicks = videoClicks
    }

    /// All tracking URLs registered for `event`.
    public func urls(for event: VASTTrackingEvent) -> [URL] {
        trackingEvents.filter { $0.event == event }.map(\.url)
    }

    /// The best media file to play: prefer an HLS stream, then the highest
    /// bitrate progressive file, else the first available.
    public var preferredMediaFile: MediaFile? {
        if let hls = mediaFiles.first(where: { $0.isHLS }) { return hls }
        let progressive = mediaFiles
            .filter { !$0.isHLS }
            .sorted { ($0.bitrate ?? 0) > ($1.bitrate ?? 0) }
        return progressive.first ?? mediaFiles.first
    }
}

/// One `<Tracking event="...">` URL.
public struct TrackingEntry: Equatable, Sendable {
    public var event: VASTTrackingEvent
    public var url: URL

    public init(event: VASTTrackingEvent, url: URL) {
        self.event = event
        self.url = url
    }
}

/// A single playable rendition referenced by a `<MediaFile>`.
public struct MediaFile: Equatable, Sendable {
    public var url: URL
    public var type: String?
    public var delivery: String?
    public var width: Int?
    public var height: Int?
    public var bitrate: Int?

    public init(url: URL,
                type: String? = nil,
                delivery: String? = nil,
                width: Int? = nil,
                height: Int? = nil,
                bitrate: Int? = nil) {
        self.url = url
        self.type = type
        self.delivery = delivery
        self.width = width
        self.height = height
        self.bitrate = bitrate
    }

    /// `true` when this rendition is an HLS playlist (by MIME type or extension).
    public var isHLS: Bool {
        if let type = type?.lowercased(),
           type.contains("mpegurl") || type.contains("m3u8") { return true }
        return url.pathExtension.lowercased() == "m3u8"
    }
}

/// `<VideoClicks>` — the destination plus extra click-tracking beacons.
public struct VideoClicks: Equatable, Sendable {
    public var clickThrough: URL?
    public var clickTracking: [URL]

    public init(clickThrough: URL? = nil, clickTracking: [URL] = []) {
        self.clickThrough = clickThrough
        self.clickTracking = clickTracking
    }
}
