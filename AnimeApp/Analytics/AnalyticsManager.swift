//  AnalyticsManager.swift
//
//  The centralised analytics **event bus** — a publisher/subscriber hub modelled
//  on the `EventBus` pattern from the WBD-Learning samples (subscribe → token,
//  unsubscribe(token), publish(event)).
//
//  One shared instance is used throughout the app. Features *publish* events;
//  two kinds of observers receive them:
//
//   1. `AnalyticsProvider`s  - long-lived SDK sinks (Console, AmexPanel, Firebase…)
//      registered once in `bootstrap()`.
//   2. Closure *subscribers* - ad-hoc observers that get a `SubscriberToken` back
//      so they can `unsubscribe(_:)` later (handy for debug overlays or tests).
//
//  This keeps event firing completely decoupled from whichever analytics vendors
//  are wired up - add or remove sinks without touching a single call site.
//

import Foundation

// MARK: - AnalyticsManager

final class AnalyticsManager {

    /// Shared instance used across the whole application.
    static let shared = AnalyticsManager()

    /// A lightweight closure observer of published events.
    typealias Subscriber = (AnalyticsEvent) -> Void
    /// Opaque handle returned by ``subscribe(_:)`` and passed to ``unsubscribe(_:)``.
    typealias SubscriberToken = UUID

    private let lock = NSLock()
    private var providers: [AnalyticsProvider] = []
    private var subscribers: [SubscriberToken: Subscriber] = [:]

    /// Internal (not private) so tests can create an isolated bus instead of
    /// mutating the shared singleton. Production code should use ``shared``.
    init() {}

    // MARK: Providers (persistent SDK sinks)

    /// Adds a provider that will receive all subsequently published events.
    func register(_ provider: AnalyticsProvider) {
        lock.lock(); defer { lock.unlock() }
        providers.append(provider)
    }

    // MARK: Subscribers (closure observers, token-based)

    /// Subscribes a closure to every published event. Returns a token used to
    /// ``unsubscribe(_:)`` later.
    @discardableResult
    func subscribe(_ handler: @escaping Subscriber) -> SubscriberToken {
        let token = UUID()
        lock.lock(); subscribers[token] = handler; lock.unlock()
        return token
    }

    /// Removes a previously registered closure subscriber.
    func unsubscribe(_ token: SubscriberToken) {
        lock.lock(); subscribers.removeValue(forKey: token); lock.unlock()
    }

    /// Number of active closure subscribers (excludes providers). Useful in tests.
    var subscriberCount: Int {
        lock.lock(); defer { lock.unlock() }
        return subscribers.count
    }

    // MARK: Publishing (the "event fire")

    /// Publishes `event` to every provider and every closure subscriber.
    func publish(_ event: AnalyticsEvent) {
        lock.lock()
        let providerSnapshot = providers
        let subscriberSnapshot = Array(subscribers.values)
        lock.unlock()

        providerSnapshot.forEach { $0.record(event) }
        subscriberSnapshot.forEach { $0(event) }
    }

    // MARK: Lifecycle

    /// Removes all providers and subscribers (mainly for tests).
    func reset() {
        lock.lock(); defer { lock.unlock() }
        providers.removeAll()
        subscribers.removeAll()
    }

    /// Registers the default set of providers and fires the launch event.
    /// Call once from `AppDelegate`. New analytics vendors are added here.
    func bootstrap() {
        register(ConsoleAnalyticsProvider())
        register(AmexPanelAnalyticsProvider())
        register(FirebaseAnalyticsProvider())
        publish(AppLifecycleEvent.appLaunch)
    }
}
