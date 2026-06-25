//
//  AdLoggerBridge.swift
//  AnimeApp
//
//  Adapts AdSDK's `AdSDKLogger` to the app's analytics pipeline: it translates
//  ad lifecycle events and stream-metrics snapshots into `AdAnalyticsEvent`s and
//  emits them through `AnalyticsManager.shared`. Hold a strong reference where the
//  player lives (the coordinator only keeps a weak `logger`).
//

import Foundation
import AdSDK
import AnalyticsKit

final class AdLoggerBridge: AdSDKLogger {

    func adSDK(didEmit event: AdEvent) {
        guard let mapped = Self.map(event) else { return }
        AnalyticsManager.shared.emit(mapped)
    }

    func adSDK(didCollect metrics: StreamMetrics) {
        AnalyticsManager.shared.emit(AdAnalyticsEvent.streamMetrics(metrics))
    }

    private static func map(_ event: AdEvent) -> AdAnalyticsEvent? {
        switch event {
        case let .breakStarted(breakID, adCount):
            return .breakStarted(breakID: breakID, adCount: adCount)
        case let .adStarted(adID, _, index, count):
            return .adStarted(adID: adID, index: index, count: count)
        case let .quartile(adID, quartile):
            return .quartile(adID: adID, quartile: quartile.rawValue)
        case let .adSkipped(adID):
            return .adSkipped(adID: adID)
        case let .adClicked(adID, _):
            return .adClicked(adID: adID)
        case let .adCompleted(adID):
            return .adCompleted(adID: adID)
        case let .breakCompleted(breakID):
            return .breakCompleted(breakID: breakID)
        case let .adError(_, message):
            return .adError(message: message)
        case .adProgress:
            // Too high-frequency for analytics; drive UI only.
            return nil
        }
    }
}
