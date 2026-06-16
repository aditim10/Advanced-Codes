//
//  AnalyticsManagerTests.swift
//  AnimeAppTests
//
//  Exercises the analytics *event bus*: publishing to providers, the token-based
//  subscribe/unsubscribe flow, and the fan-out to multiple sinks.
//

import XCTest
@testable import AnimeApp

final class AnalyticsManagerTests: XCTestCase {

    private var bus: AnalyticsManager!

    override func setUp() {
        super.setUp()
        bus = AnalyticsManager()   // isolated instance, not the shared singleton
    }

    override func tearDown() {
        bus = nil
        super.tearDown()
    }

    func testPublishForwardsToRegisteredProvider() {
        let spy = SpyAnalyticsProvider()
        bus.register(spy)

        bus.publish(AppLifecycleEvent.appLaunch)
        bus.publish(LoginAnalyticsEvent.success(email: "a@b.com"))

        XCTAssertEqual(spy.names, ["app_launch", "login_success"])
    }

    func testPublishFansOutToMultipleProviders() {
        let a = SpyAnalyticsProvider()
        let b = SpyAnalyticsProvider()
        bus.register(a)
        bus.register(b)

        bus.publish(HomeAnalyticsEvent.loadSuccess(sectionCount: 3))

        XCTAssertEqual(a.names, ["home_load_success"])
        XCTAssertEqual(b.names, ["home_load_success"])
    }

    func testEventCarriesPayload() {
        let spy = SpyAnalyticsProvider()
        bus.register(spy)

        bus.publish(SearchAnalyticsEvent.resultSuccess(query: "naruto", count: 7))

        let event = spy.events.first
        XCTAssertEqual(event?.name, "search_result_success")
        XCTAssertEqual(event?.parameters["query"] as? String, "naruto")
        XCTAssertEqual(event?.parameters["count"] as? Int, 7)
    }

    func testSubscribeReceivesEventsAndReturnsToken() {
        var received: [String] = []
        let token = bus.subscribe { received.append($0.name) }
        XCTAssertEqual(bus.subscriberCount, 1)

        bus.publish(AppLifecycleEvent.appLaunch)
        XCTAssertEqual(received, ["app_launch"])

        // Token is what we use to detach later.
        bus.unsubscribe(token)
        XCTAssertEqual(bus.subscriberCount, 0)
    }

    func testUnsubscribeStopsDelivery() {
        var count = 0
        let token = bus.subscribe { _ in count += 1 }

        bus.publish(AppLifecycleEvent.appLaunch)
        bus.unsubscribe(token)
        bus.publish(AppLifecycleEvent.appLaunch)

        XCTAssertEqual(count, 1, "Event after unsubscribe should not be delivered")
    }

    func testResetRemovesProvidersAndSubscribers() {
        let spy = SpyAnalyticsProvider()
        bus.register(spy)
        bus.subscribe { _ in }

        bus.reset()
        bus.publish(AppLifecycleEvent.appLaunch)

        XCTAssertTrue(spy.events.isEmpty)
        XCTAssertEqual(bus.subscriberCount, 0)
    }
}
