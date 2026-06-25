//
//  AdSDKLogger.swift
//  AdSDK
//
//  The sink the host implements to receive ad events and stream metrics, so the
//  app can route them into its own analytics pipeline (e.g. AnalyticsKit). Metrics
//  delivery is optional via the default no-op.
//

import Foundation

public protocol AdSDKLogger: AnyObject {
    /// A high-level ad lifecycle event occurred.
    func adSDK(didEmit event: AdEvent)
    /// A stream-metrics snapshot was collected (periodic + at session end).
    func adSDK(didCollect metrics: StreamMetrics)
}

public extension AdSDKLogger {
    func adSDK(didCollect metrics: StreamMetrics) {}
}
