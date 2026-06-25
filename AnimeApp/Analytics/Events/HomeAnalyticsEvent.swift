//  HomeAnalyticsEvent.swift
//
//  Analytics events for the Home screen.

import Foundation
import AnalyticsKit

private enum EventName {
    static let loadSuccess = "home_load_success"
    static let loadFailure = "home_load_failure"
    static let paginate = "home_paginate"
}

private enum ParamKey {
    static let sectionCount = "section_count"
    static let reason = "reason"
    static let page = "page"
}

enum HomeAnalyticsEvent: AnalyticsEvent {
    /// Home finished its initial load successfully.
    case loadSuccess(sectionCount: Int)
    case loadFailure(reason: String)
    /// User scrolled near the bottom and a new page/section was requested.
    case paginate(page: Int)

    var name: String {
        switch self {
        case .loadSuccess: return EventName.loadSuccess
        case .loadFailure: return EventName.loadFailure
        case .paginate: return EventName.paginate
        }
    }

    var parameters: [String: Any] {
        switch self {
        case .loadSuccess(let count): return [ParamKey.sectionCount: count]
        case .loadFailure(let reason): return [ParamKey.reason: reason]
        case .paginate(let page): return [ParamKey.page: page]
        }
    }
}
