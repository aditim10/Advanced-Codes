//  SeeAllAnalyticsEvent.swift
//
//  Analytics events for the "See All" section listing screen.

import Foundation
import AnalyticsKit

private enum EventName {
    static let open = "see_all_open"
    static let paginate = "see_all_paginate"
}

private enum ParamKey {
    static let section = "section"
    static let page = "page"
}

enum SeeAllAnalyticsEvent: AnalyticsEvent {
    case open(section: String)
    case paginate(section: String, page: Int)

    var name: String {
        switch self {
        case .open: return EventName.open
        case .paginate: return EventName.paginate
        }
    }

    var parameters: [String: Any] {
        switch self {
        case .open(let section):
            return [ParamKey.section: section]
        case .paginate(let section, let page):
            return [ParamKey.section: section, ParamKey.page: page]
        }
    }
}
