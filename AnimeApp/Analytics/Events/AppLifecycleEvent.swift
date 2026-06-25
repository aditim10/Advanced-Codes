//  AppLifecycleEvent.swift
//
//  Analytics events for app-wide lifecycle moments. To add a new lifecycle
//  event, add a case here and map it to a name below.

import Foundation
import AnalyticsKit

private enum EventName {
    static let appLaunch = "app_launch"
}

enum AppLifecycleEvent: AnalyticsEvent {
    /// Fired once when the app finishes launching.
    case appLaunch

    var name: String {
        switch self {
        case .appLaunch: return EventName.appLaunch
        }
    }
}
