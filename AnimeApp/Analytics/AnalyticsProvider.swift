//  AnalyticsProvider.swift
//
//  The plug-in point for analytics back-ends. Any SDK (AmexPanel, Firebase,
//  Mixpanel, an in-house endpoint, …) becomes available to the whole app simply
//  by conforming to this protocol and registering with `AnalyticsManager`.
//

import Foundation

/// A destination that receives every tracked ``AnalyticsEvent``.
protocol AnalyticsProvider: AnyObject {

    /// Human-readable provider name, handy for debugging which sinks are active.
    var name: String { get }

    /// Forward `event` to the underlying analytics back-end.
    func record(_ event: AnalyticsEvent)
}
