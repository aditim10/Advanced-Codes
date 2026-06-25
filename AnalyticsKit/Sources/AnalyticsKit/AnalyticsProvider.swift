//  AnalyticsProvider.swift
//  AnalyticsKit
//
//  The plug-in point for analytics back-ends. Any SDK (MixPanel, Firebase,
//  an in-house endpoint, …) becomes available to the consuming app simply by
//  conforming to this protocol and registering with `AnalyticsManager`.
//

import Foundation

/// A destination that receives every tracked ``AnalyticsEvent``.
public protocol AnalyticsProvider: AnyObject {

    /// Human-readable provider name, handy for debugging which sinks are active.
    var name: String { get }

    /// Forward `event` to the underlying analytics back-end.
    func record(_ event: AnalyticsEvent)
}
