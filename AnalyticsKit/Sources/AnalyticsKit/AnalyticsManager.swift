//  AnalyticsManager.swift
//  AnalyticsKit
//
//  The centralised analytics **event bus** — a publisher/subscriber hub modelled
//  on the `EventBus` pattern (subscribe → token, unsubscribe(token), emit(event)).
//
//  One shared instance is used throughout the consuming app. Features *emit*
//  events; two kinds of observers receive them:
//
//   1. `AnalyticsProvider`s  - long-lived SDK sinks (Console, MixPanel, Firebase…)
//      registered once via `bootstrap(_:launchEvent:)`.
//   2. Closure *subscribers* - ad-hoc observers that get a `SubscriberToken` back
//      so they can `unsubscribe(_:)` later (handy for debug overlays or tests).
//
//  This keeps event firing completely decoupled from whichever analytics vendors
//  are wired up - add or remove sinks without touching a single call site.
//

import Foundation

// MARK: - AnalyticsManager

public final class AnalyticsManager {

    /// Shared instance used across the whole application.
    public static let shared = AnalyticsManager()

    /// How emitted events are delivered to providers.
    public enum Delivery {
        /// Hand off to a background queue so emitting never blocks the caller —
        /// keeps provider work (network/disk/SDK) off the UI thread. Production
        /// default.
        case asyncBackground
        /// Deliver inline on the caller's thread. Used by tests so they can assert
        /// on provider state synchronously right after emitting.
        case synchronous
    }

    /// A lightweight closure observer of published events.
    public typealias Subscriber = (AnalyticsEvent) -> Void
    /// Opaque handle returned by ``subscribe(_:)`` and passed to ``unsubscribe(_:)``.
    public typealias SubscriberToken = UUID

    /// Serialises access to `providers`/`subscribers` without an `NSLock`. It's a
    /// *concurrent* queue: reads (`sync`) run in parallel, while mutations use a
    /// `.barrier` so they get exclusive access. This is the reader–writer pattern —
    /// thread-safe, and (unlike a plain lock held across callbacks) it never holds
    /// the critical section while notifying providers, so re-entrant `emit`
    /// calls can't deadlock.
    private let queue = DispatchQueue(label: "com.animex.analytics.bus", attributes: .concurrent)

    /// Serial queue that actually delivers events to providers. Providers can do
    /// real work in `record(_:)` (network, disk, SDK calls), so delivery happens
    /// *here* — never on the caller's thread (usually main) — to avoid UI jank.
    /// Serial so events reach each provider in the order they were emitted.
    private let deliveryQueue = DispatchQueue(label: "com.animex.analytics.delivery", qos: .utility)

    private var providers: [AnalyticsProvider] = []
    private var subscribers: [SubscriberToken: Subscriber] = [:]
    private var didBootstrap = false
    private let delivery: Delivery

    /// Creates a bus. Tests can create an isolated instance instead of mutating
    /// the shared singleton; production code should use ``shared``.
    /// - Parameter delivery: how events reach providers; defaults to a background
    ///   queue. Tests pass `.synchronous` for deterministic assertions.
    public init(delivery: Delivery = .asyncBackground) {
        self.delivery = delivery
    }

    // MARK: Providers (persistent SDK sinks)

    /// Adds a provider that will receive all subsequently published events.
    ///
    /// Idempotent by concrete type: registering a second provider of a type that's
    /// already registered is a no-op, so an accidental double-registration can't
    /// cause events to be recorded twice.
    public func register(_ provider: AnalyticsProvider) {
        queue.sync(flags: .barrier) {
            guard !providers.contains(where: { type(of: $0) == type(of: provider) }) else { return }
            providers.append(provider)
        }
    }

    // MARK: Subscribers (closure observers, token-based)

    /// Subscribes a closure to every published event. Returns a token used to
    /// ``unsubscribe(_:)`` later.
    @discardableResult
    public func subscribe(_ handler: @escaping Subscriber) -> SubscriberToken {
        let token = UUID()
        queue.sync(flags: .barrier) { subscribers[token] = handler }
        return token
    }

    /// Removes a previously registered closure subscriber.
    public func unsubscribe(_ token: SubscriberToken) {
        queue.sync(flags: .barrier) { _ = subscribers.removeValue(forKey: token) }
    }

    /// Number of active closure subscribers (excludes providers). Useful in tests.
    public var subscriberCount: Int {
        queue.sync { subscribers.count }
    }

    // MARK: Emitting (the "event fire")

    /// Emits `event` to every provider and every closure subscriber.
    public func emit(_ event: AnalyticsEvent) {
        // Grab a consistent snapshot under the queue, then notify *outside* it so a
        // slow (or re-entrant) provider can never stall the bus or deadlock.
        let providerSnapshot: [AnalyticsProvider]
        let subscriberSnapshot: [Subscriber]
        (providerSnapshot, subscriberSnapshot) = queue.sync {
            (providers, Array(subscribers.values))
        }

        // Providers may block (network/disk/SDK work). In production we hand them
        // off to the background delivery queue so emitting never stalls the
        // caller's thread (usually main). Tests opt into synchronous delivery.
        if !providerSnapshot.isEmpty {
            switch delivery {
            case .asyncBackground:
                deliveryQueue.async {
                    providerSnapshot.forEach { $0.record(event) }
                }
            case .synchronous:
                providerSnapshot.forEach { $0.record(event) }
            }
        }
        // Subscribers are lightweight in-app observers (debug overlays, tests);
        // they run synchronously on the caller's thread.
        subscriberSnapshot.forEach { $0(event) }
    }

    // MARK: Lifecycle

    /// Removes all providers and subscribers (mainly for tests).
    public func reset() {
        queue.sync(flags: .barrier) {
            providers.removeAll()
            subscribers.removeAll()
            didBootstrap = false
        }
    }

    /// Registers the client's set of providers and (optionally) fires a launch
    /// event. Call once from the app's launch path. Providers are client-specific,
    /// so the app supplies them here rather than the bus hard-coding any vendor.
    ///
    /// Idempotent: a second call is a no-op, so providers are never registered
    /// (and the launch event never fired) twice if this is reached more than once.
    public func bootstrap(_ providers: [AnalyticsProvider], launchEvent: AnalyticsEvent? = nil) {
        let shouldBootstrap: Bool = queue.sync(flags: .barrier) {
            guard !didBootstrap else { return false }
            didBootstrap = true
            return true
        }
        guard shouldBootstrap else { return }

        providers.forEach { register($0) }
        if let launchEvent {
            emit(launchEvent)
        }
    }
}
