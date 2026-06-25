//  AdAnalyticsEvent.swift
//
//  Analytics events for the ad / VMAP mid-roll flow, mirroring the
//  `HomeAnalyticsEvent` pattern. `AdLoggerBridge` maps AdSDK's `AdEvent` and
//  `StreamMetrics` onto these and emits them through `AnalyticsManager`.

import Foundation
import AnalyticsKit
import AdSDK

private enum EventName {
    static let breakStarted = "ad_break_started"
    static let adStarted = "ad_started"
    static let quartile = "ad_quartile"
    static let adSkipped = "ad_skipped"
    static let adClicked = "ad_clicked"
    static let adCompleted = "ad_completed"
    static let breakCompleted = "ad_break_completed"
    static let adError = "ad_error"
    static let streamMetrics = "stream_metrics"
}

private enum ParamKey {
    static let breakID = "break_id"
    static let adID = "ad_id"
    static let adCount = "ad_count"
    static let index = "index"
    static let count = "count"
    static let quartile = "quartile"
    static let message = "message"
}

enum AdAnalyticsEvent: AnalyticsEvent {
    case breakStarted(breakID: String, adCount: Int)
    case adStarted(adID: String, index: Int, count: Int)
    case quartile(adID: String, quartile: String)
    case adSkipped(adID: String)
    case adClicked(adID: String)
    case adCompleted(adID: String)
    case breakCompleted(breakID: String)
    case adError(message: String)
    case streamMetrics(StreamMetrics)

    var name: String {
        switch self {
        case .breakStarted:   return EventName.breakStarted
        case .adStarted:      return EventName.adStarted
        case .quartile:       return EventName.quartile
        case .adSkipped:      return EventName.adSkipped
        case .adClicked:      return EventName.adClicked
        case .adCompleted:    return EventName.adCompleted
        case .breakCompleted: return EventName.breakCompleted
        case .adError:        return EventName.adError
        case .streamMetrics:  return EventName.streamMetrics
        }
    }

    var parameters: [String: Any] {
        switch self {
        case let .breakStarted(breakID, adCount):
            return [ParamKey.breakID: breakID, ParamKey.adCount: adCount]
        case let .adStarted(adID, index, count):
            return [ParamKey.adID: adID, ParamKey.index: index, ParamKey.count: count]
        case let .quartile(adID, quartile):
            return [ParamKey.adID: adID, ParamKey.quartile: quartile]
        case let .adSkipped(adID):
            return [ParamKey.adID: adID]
        case let .adClicked(adID):
            return [ParamKey.adID: adID]
        case let .adCompleted(adID):
            return [ParamKey.adID: adID]
        case let .breakCompleted(breakID):
            return [ParamKey.breakID: breakID]
        case let .adError(message):
            return [ParamKey.message: message]
        case let .streamMetrics(metrics):
            return metrics.dictionary
        }
    }
}
