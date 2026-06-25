//
//  VASTWrapperResolver.swift
//  AdSDK
//
//  Resolves VAST `Wrapper` ads into playable `InLine` ads. A wrapper is a redirect
//  (`VASTAdTagURI`) to another VAST document; per spec, the wrapper's own
//  impressions / error / tracking beacons must be carried forward and merged into
//  whatever inline ad it ultimately resolves to. Chains are followed up to
//  `maxDepth` to avoid infinite redirects.
//

import Foundation

public actor VASTWrapperResolver {

    public struct Configuration: Sendable {
        public var maxDepth: Int
        public init(maxDepth: Int = 5) { self.maxDepth = maxDepth }
    }

    public enum ResolverError: Error, Equatable {
        case maxDepthExceeded
        case emptyResponse
    }

    private let session: URLSession
    private let configuration: Configuration

    public init(session: URLSession = .shared, configuration: Configuration = .init()) {
        self.session = session
        self.configuration = configuration
    }

    /// Resolves every wrapper in `vast` to inline ads (in place of the wrapper),
    /// merging carried-forward tracking. Inline ads pass through untouched. Ads
    /// that fail to resolve (network error, depth limit) are dropped.
    public func resolve(_ vast: VAST) async -> VAST {
        var resolved: [VASTAd] = []
        for ad in vast.orderedAds {
            switch ad.content {
            case .inLine:
                resolved.append(ad)
            case .wrapper(let wrapper):
                let inlineAds = (try? await resolveWrapper(wrapper, depth: 0)) ?? []
                // Preserve the wrapper ad's id/sequence on the first resolved ad.
                for (index, child) in inlineAds.enumerated() {
                    resolved.append(VASTAd(
                        id: index == 0 ? (ad.id ?? child.id) : child.id,
                        sequence: index == 0 ? (ad.sequence ?? child.sequence) : child.sequence,
                        content: child.content))
                }
            }
        }
        return VAST(version: vast.version, ads: resolved)
    }

    /// Fetches and fully resolves a remote VAST tag.
    public func resolve(tagURL: URL) async throws -> VAST {
        let vast = try await fetchVAST(tagURL)
        return await resolve(vast)
    }

    // MARK: - Private

    private func resolveWrapper(_ wrapper: Wrapper, depth: Int) async throws -> [VASTAd] {
        guard depth < configuration.maxDepth else { throw ResolverError.maxDepthExceeded }

        let childVAST = try await fetchVAST(wrapper.vastAdTagURI)
        var output: [VASTAd] = []

        for ad in childVAST.orderedAds {
            switch ad.content {
            case .inLine(let inLine):
                output.append(VASTAd(id: ad.id, sequence: ad.sequence,
                                     content: .inLine(merge(wrapper, into: inLine))))
            case .wrapper(let childWrapper):
                guard wrapper.followAdditionalWrappers else { continue }
                let grandchildren = try await resolveWrapper(childWrapper, depth: depth + 1)
                // Merge THIS wrapper's beacons into each fully-resolved descendant.
                for grandchild in grandchildren {
                    if let inLine = grandchild.inLine {
                        output.append(VASTAd(id: grandchild.id, sequence: grandchild.sequence,
                                             content: .inLine(merge(wrapper, into: inLine))))
                    }
                }
            }
            if !wrapper.allowMultipleAds, !output.isEmpty { break }
        }
        return output
    }

    private func fetchVAST(_ url: URL) async throws -> VAST {
        let (data, _) = try await session.data(from: url)
        guard !data.isEmpty else { throw ResolverError.emptyResponse }
        return try VASTParser.parse(data: data)
    }

    /// Merges a wrapper's impressions, errors, and linear tracking / click
    /// tracking into an inline ad (the wrapper's beacons fire alongside the
    /// inline ad's own).
    private func merge(_ wrapper: Wrapper, into inLine: InLine) -> InLine {
        var result = inLine
        result.impressions = wrapper.impressions + inLine.impressions
        result.errors = wrapper.errors + inLine.errors

        let wrapperLinears = wrapper.creatives.compactMap(\.linear)
        let extraTracking = wrapperLinears.flatMap(\.trackingEvents)
        let extraClickTracking = wrapperLinears.compactMap(\.videoClicks).flatMap(\.clickTracking)

        guard !extraTracking.isEmpty || !extraClickTracking.isEmpty else { return result }

        result.creatives = inLine.creatives.map { creative in
            guard var linear = creative.linear else { return creative }
            linear.trackingEvents = linear.trackingEvents + extraTracking
            if !extraClickTracking.isEmpty {
                var clicks = linear.videoClicks ?? VideoClicks()
                clicks.clickTracking += extraClickTracking
                linear.videoClicks = clicks
            }
            var updated = creative
            updated.linear = linear
            return updated
        }
        return result
    }
}
