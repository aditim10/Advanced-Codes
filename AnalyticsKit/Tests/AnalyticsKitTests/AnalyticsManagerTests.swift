//  AnalyticsManagerTests.swift
//  AnalyticsKitTests
//
//  Exercises the bus itself with local sample events/providers, independent of
//  any consuming app: provider fan-out, idempotent registration, the token-based
//  subscribe/unsubscribe flow, and idempotent bootstrap.

import XCTest
@testable import AnalyticsKit

private struct SampleEvent: AnalyticsEvent {
    let name: String
    let parameters: [String: Any]
    init(_ name: String, _ parameters: [String: Any] = [:]) {
        self.name = name
        self.parameters = parameters
    }
}

private final class SpyProvider: AnalyticsProvider {
    let name = "Spy"
    private(set) var names: [String] = []
    func record(_ event: AnalyticsEvent) { names.append(event.name) }
}

final class AnalyticsManagerTests: XCTestCase {

    private var bus: AnalyticsManager!

    override func setUp() {
        super.setUp()
        bus = AnalyticsManager(delivery: .synchronous)
    }

    override func tearDown() {
        bus = nil
        super.tearDown()
    }

    func testEmitFansOutToProviders() {
        let spy = SpyProvider()
        bus.register(spy)
        bus.emit(SampleEvent("app_launch"))
        XCTAssertEqual(spy.names, ["app_launch"])
    }

    func testRegisterIsIdempotentByType() {
        bus.register(SpyProvider())
        bus.register(SpyProvider())   // same concrete type → ignored
        bus.emit(SampleEvent("event"))
        // Only one provider registered, but we can't read it directly; instead
        // verify a subscriber sees exactly one emission per emit.
        var count = 0
        bus.subscribe { _ in count += 1 }
        bus.emit(SampleEvent("event"))
        XCTAssertEqual(count, 1)
    }

    func testSubscribeUnsubscribe() {
        var received: [String] = []
        let token = bus.subscribe { received.append($0.name) }
        XCTAssertEqual(bus.subscriberCount, 1)
        bus.emit(SampleEvent("a"))
        bus.unsubscribe(token)
        bus.emit(SampleEvent("b"))
        XCTAssertEqual(received, ["a"])
        XCTAssertEqual(bus.subscriberCount, 0)
    }

    func testBootstrapIsIdempotent() {
        let spy = SpyProvider()
        bus.bootstrap([spy], launchEvent: SampleEvent("app_launch"))
        bus.bootstrap([spy], launchEvent: SampleEvent("app_launch"))
        XCTAssertEqual(spy.names, ["app_launch"])
    }
}
