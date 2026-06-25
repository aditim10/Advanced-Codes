//
//  AdSourceResolverTests.swift
//  AdSDKTests
//
//  Exercises the `AdSourceResolving` seam offline: an inline VAST source resolves
//  to a playable pod without any network (only wrappers hit the network).
//

import XCTest
@testable import AdSDK

final class AdSourceResolverTests: XCTestCase {

    private func inlineSource() throws -> AdSource {
        let vmap = try XCTUnwrap(AdSampleSources.sampleVMAP())
        return vmap.adBreaks[0].adSource   // inline 2-ad pod
    }

    func testResolvesInlineVASTToPod() async throws {
        let source = try inlineSource()
        let resolver = DefaultAdSourceResolver()
        let pod = await resolver.resolvePod(from: source, maxAds: nil)
        XCTAssertEqual(pod.count, 2)
        XCTAssertEqual(pod.first?.title, "Sample Mid-roll Ad A")
    }

    func testHonoursMaxAdsCap() async throws {
        let source = try inlineSource()
        let resolver = DefaultAdSourceResolver()
        let pod = await resolver.resolvePod(from: source, maxAds: 1)
        XCTAssertEqual(pod.count, 1)
    }
}
