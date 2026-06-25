//
//  VMAPParserTests.swift
//  AdSDKTests
//

import XCTest
@testable import AdSDK

final class VMAPParserTests: XCTestCase {

    func testParsesBundledSampleVMAP() throws {
        let vmap = try XCTUnwrap(AdSampleSources.sampleVMAP())
        XCTAssertEqual(vmap.adBreaks.count, 2)

        let first = vmap.adBreaks[0]
        XCTAssertEqual(first.breakId, "midroll-1")
        XCTAssertEqual(first.timeOffset, .percentage(0.25))
        XCTAssertTrue(first.isMidRoll)

        let second = vmap.adBreaks[1]
        XCTAssertEqual(second.breakId, "midroll-2")
        XCTAssertEqual(second.timeOffset, .percentage(0.60))
    }

    func testInlineVASTAdDataIsParsed() throws {
        let vmap = try XCTUnwrap(AdSampleSources.sampleVMAP())
        guard case .vast(let vast) = vmap.adBreaks[0].adSource else {
            return XCTFail("Expected inline VAST ad source")
        }
        // midroll-1 is a two-ad pod.
        XCTAssertEqual(vast.ads.count, 2)
        XCTAssertEqual(vast.orderedAds.first?.inLine?.adTitle, "Sample Mid-roll Ad A")
    }

    func testTimeOffsetParsing() {
        XCTAssertEqual(TimeOffset.parse("start"), .start)
        XCTAssertEqual(TimeOffset.parse("end"), .end)
        XCTAssertEqual(TimeOffset.parse("50%"), .percentage(0.5))
        XCTAssertEqual(TimeOffset.parse("#2"), .position(2))
        XCTAssertEqual(TimeOffset.parse("00:01:30"), .seconds(90))
        XCTAssertEqual(TimeOffset.parse("00:00:05.5"), .seconds(5.5))
        XCTAssertNil(TimeOffset.parse("garbage"))
    }

    func testTimeOffsetResolution() {
        XCTAssertEqual(TimeOffset.percentage(0.25).resolved(contentDuration: 200), 50)
        XCTAssertEqual(TimeOffset.seconds(42).resolved(contentDuration: 200), 42)
        XCTAssertEqual(TimeOffset.start.resolved(contentDuration: 200), 0)
        XCTAssertEqual(TimeOffset.end.resolved(contentDuration: 200), 200)
        XCTAssertNil(TimeOffset.position(1).resolved(contentDuration: 200))
    }

    func testRejectsNonVMAP() {
        XCTAssertThrowsError(try VMAPParser.parse(string: "<VAST></VAST>"))
    }
}
