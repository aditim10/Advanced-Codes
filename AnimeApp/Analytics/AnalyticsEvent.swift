//  AnalyticsEvent.swift
//
//  The contract every analytics event conforms to. An event is just a *name*
//  (the event type) plus a *payload* of structured info. Defining events behind
//  a protocol means new events can be added anywhere without touching the bus or
//  the providers.

import Foundation

// MARK: - AnalyticsEvent

/// A trackable event: a name plus an optional payload of contextual info.
protocol AnalyticsEvent {

    /// Stable, snake_case event name (e.g. `"app_launch"`, `"login_success"`).
    var name: String { get }

    /// Structured payload sent alongside the event (e.g. `["count": 12]`).
    var parameters: [String: Any] { get }
}

extension AnalyticsEvent {
    /// Events with no payload don't need to implement `parameters`.
    var parameters: [String: Any] { [:] }
}
