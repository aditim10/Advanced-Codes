//
//  VASTParser.swift
//  AdSDK
//
//  Turns a VAST document into the ``VAST`` model. Handles both `InLine` and
//  `Wrapper` ads, linear creatives (media files, full tracking-event set,
//  skipoffset, video clicks), impressions, errors, and ad-pod `sequence`.
//

import Foundation

public enum VASTParsingError: Error, Equatable {
    case malformed
    case notVAST
}

public enum VASTParser {

    /// Parses VAST from raw XML data.
    public static func parse(data: Data) throws -> VAST {
        guard let root = XMLTreeBuilder.build(from: data) else { throw VASTParsingError.malformed }
        return try parse(root: root)
    }

    /// Parses VAST from an XML string.
    public static func parse(string: String) throws -> VAST {
        guard let root = XMLTreeBuilder.build(from: string) else { throw VASTParsingError.malformed }
        return try parse(root: root)
    }

    /// Parses VAST from an already-built tree (used for VMAP inline `VASTAdData`).
    static func parse(root: XMLNode) throws -> VAST {
        guard root.localName == "VAST" else { throw VASTParsingError.notVAST }
        let version = root.attribute("version") ?? "4.0"
        let ads = root.children(named: "Ad").compactMap(parseAd)
        return VAST(version: version, ads: ads)
    }

    // MARK: - Ad

    private static func parseAd(_ node: XMLNode) -> VASTAd? {
        let id = node.attribute("id")
        let sequence = node.attribute("sequence").flatMap(Int.init)

        if let inLineNode = node.firstChild("InLine") {
            return VASTAd(id: id, sequence: sequence, content: .inLine(parseInLine(inLineNode)))
        }
        if let wrapperNode = node.firstChild("Wrapper"),
           let wrapper = parseWrapper(wrapperNode) {
            return VASTAd(id: id, sequence: sequence, content: .wrapper(wrapper))
        }
        return nil
    }

    private static func parseInLine(_ node: XMLNode) -> InLine {
        InLine(
            adSystem: node.childText("AdSystem"),
            adTitle: node.childText("AdTitle"),
            impressions: urls(node.children(named: "Impression")),
            errors: urls(node.children(named: "Error")),
            creatives: parseCreatives(node)
        )
    }

    private static func parseWrapper(_ node: XMLNode) -> Wrapper? {
        guard let tagText = node.childText("VASTAdTagURI"),
              let tagURL = url(from: tagText) else { return nil }
        return Wrapper(
            adSystem: node.childText("AdSystem"),
            vastAdTagURI: tagURL,
            impressions: urls(node.children(named: "Impression")),
            errors: urls(node.children(named: "Error")),
            creatives: parseCreatives(node),
            followAdditionalWrappers: node.attribute("followAdditionalWrappers").map { $0 != "false" && $0 != "0" } ?? true,
            allowMultipleAds: node.attribute("allowMultipleAds").map { $0 != "false" && $0 != "0" } ?? true
        )
    }

    // MARK: - Creatives

    private static func parseCreatives(_ adNode: XMLNode) -> [Creative] {
        guard let container = adNode.firstChild("Creatives") else { return [] }
        return container.children(named: "Creative").map { creativeNode in
            Creative(
                id: creativeNode.attribute("id"),
                sequence: creativeNode.attribute("sequence").flatMap(Int.init),
                linear: creativeNode.firstChild("Linear").map(parseLinear)
            )
        }
    }

    private static func parseLinear(_ node: XMLNode) -> Linear {
        let duration = node.childText("Duration").flatMap(VASTTime.seconds(from:))
        let skipOffset = parseSkipOffset(node.attribute("skipoffset"), duration: duration)
        return Linear(
            skipOffset: skipOffset,
            duration: duration,
            mediaFiles: parseMediaFiles(node),
            trackingEvents: parseTracking(node),
            videoClicks: parseVideoClicks(node)
        )
    }

    private static func parseMediaFiles(_ linearNode: XMLNode) -> [MediaFile] {
        guard let container = linearNode.firstChild("MediaFiles") else { return [] }
        return container.children(named: "MediaFile").compactMap { node in
            guard let mediaURL = url(from: node.text) else { return nil }
            return MediaFile(
                url: mediaURL,
                type: node.attribute("type"),
                delivery: node.attribute("delivery"),
                width: node.attribute("width").flatMap(Int.init),
                height: node.attribute("height").flatMap(Int.init),
                bitrate: node.attribute("bitrate").flatMap(Int.init)
            )
        }
    }

    private static func parseTracking(_ linearNode: XMLNode) -> [TrackingEntry] {
        guard let container = linearNode.firstChild("TrackingEvents") else { return [] }
        return container.children(named: "Tracking").compactMap { node in
            guard let name = node.attribute("event"), let trackURL = url(from: node.text) else { return nil }
            let offset = node.attribute("offset").flatMap(VASTTime.seconds(from:))
            return TrackingEntry(event: VASTTrackingEvent(name: name, offset: offset), url: trackURL)
        }
    }

    private static func parseVideoClicks(_ linearNode: XMLNode) -> VideoClicks? {
        guard let node = linearNode.firstChild("VideoClicks") else { return nil }
        let clickThrough = node.firstChild("ClickThrough").flatMap { url(from: $0.text) }
        let clickTracking = urls(node.children(named: "ClickTracking"))
        if clickThrough == nil && clickTracking.isEmpty { return nil }
        return VideoClicks(clickThrough: clickThrough, clickTracking: clickTracking)
    }

    // MARK: - Helpers

    /// Resolves a `skipoffset` attribute, which may be a clock or a percentage of
    /// the ad duration.
    private static func parseSkipOffset(_ raw: String?, duration: TimeInterval?) -> TimeInterval? {
        guard let raw = raw?.trimmingCharacters(in: .whitespaces), !raw.isEmpty else { return nil }
        if raw.hasSuffix("%"), let pct = Double(raw.dropLast()), let duration {
            return duration * (pct / 100.0)
        }
        return VASTTime.seconds(from: raw)
    }

    private static func urls(_ nodes: [XMLNode]) -> [URL] {
        nodes.compactMap { url(from: $0.text) }
    }

    private static func url(from text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return URL(string: trimmed)
    }
}

/// Clock parsing shared by VAST duration / skipoffset / tracking offsets.
enum VASTTime {
    /// Parses `HH:MM:SS(.mmm)` (or `MM:SS`, or a bare seconds value) to seconds.
    static func seconds(from value: String) -> TimeInterval? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let parts = trimmed.split(separator: ":")
        guard !parts.isEmpty, parts.count <= 3 else { return nil }
        var seconds: TimeInterval = 0
        for part in parts {
            guard let component = Double(part) else { return nil }
            seconds = seconds * 60 + component
        }
        return seconds
    }
}
