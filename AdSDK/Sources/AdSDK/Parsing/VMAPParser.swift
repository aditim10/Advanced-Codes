//
//  VMAPParser.swift
//  AdSDK
//
//  Turns a VMAP document into the ``VMAP`` model. Each `<vmap:AdBreak>` carries a
//  `timeOffset`, a break type, and an `<vmap:AdSource>` that is either inline VAST
//  (`<vmap:VASTAdData>`) or a remote tag (`<vmap:AdTagURI>`).
//

import Foundation

public enum VMAPParsingError: Error, Equatable {
    case malformed
    case notVMAP
}

public enum VMAPParser {

    /// Parses VMAP from raw XML data.
    public static func parse(data: Data) throws -> VMAP {
        guard let root = XMLTreeBuilder.build(from: data) else { throw VMAPParsingError.malformed }
        return try parse(root: root)
    }

    /// Parses VMAP from an XML string.
    public static func parse(string: String) throws -> VMAP {
        guard let root = XMLTreeBuilder.build(from: string) else { throw VMAPParsingError.malformed }
        return try parse(root: root)
    }

    static func parse(root: XMLNode) throws -> VMAP {
        guard root.localName == "VMAP" else { throw VMAPParsingError.notVMAP }
        let version = root.attribute("version") ?? "1.0"
        let breaks = root.children(named: "AdBreak").compactMap(parseAdBreak)
        return VMAP(version: version, adBreaks: breaks)
    }

    private static func parseAdBreak(_ node: XMLNode) -> AdBreak? {
        guard let offsetRaw = node.attribute("timeOffset"),
              let offset = TimeOffset.parse(offsetRaw) else { return nil }
        guard let sourceNode = node.firstChild("AdSource"),
              let source = parseAdSource(sourceNode) else { return nil }

        let breakTypes = (node.attribute("breakType") ?? "linear")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }

        return AdBreak(
            timeOffset: offset,
            breakTypes: breakTypes,
            breakId: node.attribute("breakId"),
            adSource: source
        )
    }

    private static func parseAdSource(_ node: XMLNode) -> AdSource? {
        // Inline VAST embedded directly in the VMAP.
        if let vastData = node.firstChild("VASTAdData"),
           let vastRoot = vastData.firstChild("VAST"),
           let vast = try? VASTParser.parse(root: vastRoot) {
            return .vast(vast)
        }
        // Remote VAST tag.
        if let tagText = node.firstChild("AdTagURI")?.text,
           let tagURL = URL(string: tagText.trimmingCharacters(in: .whitespacesAndNewlines)) {
            return .adTagURI(tagURL)
        }
        return nil
    }
}
