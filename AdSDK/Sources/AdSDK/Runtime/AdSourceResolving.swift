//
//  AdSourceResolving.swift
//  AdSDK
//
//  Turns a VMAP ad source (inline VAST or a remote tag) into a ready-to-play ad
//  pod. Behind a protocol so the coordinator depends on the *capability* rather
//  than the concrete `VASTWrapperResolver` + `PlayableAd` building — making it
//  trivial to inject a deterministic resolver in tests.
//

import Foundation

public protocol AdSourceResolving: Sendable {
    /// Resolves `source` (resolving any VAST wrappers) and builds the playable
    /// pod, capped to `maxAds` when non-nil.
    func resolvePod(from source: AdSource, maxAds: Int?) async -> [PlayableAd]
}

/// Default resolver: resolves wrappers over the network via ``VASTWrapperResolver``
/// then maps the inline VAST to ``PlayableAd``s.
public final class DefaultAdSourceResolver: AdSourceResolving {

    private let wrapperResolver: VASTWrapperResolver

    public init(wrapperResolver: VASTWrapperResolver = VASTWrapperResolver()) {
        self.wrapperResolver = wrapperResolver
    }

    public func resolvePod(from source: AdSource, maxAds: Int?) async -> [PlayableAd] {
        let resolved: VAST
        switch source {
        case .vast(let vast):
            resolved = await wrapperResolver.resolve(vast)
        case .adTagURI(let url):
            guard let vast = try? await wrapperResolver.resolve(tagURL: url) else { return [] }
            resolved = vast
        }
        return PlayableAd.pod(from: resolved, maxAds: maxAds)
    }
}
