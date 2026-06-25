//  SearchAnalyticsEvent.swift
//
//  Analytics events for the Search screen.

import Foundation
import AnalyticsKit

private enum EventName {
    static let query = "search_query"
    static let resultSuccess = "search_result_success"
    static let resultFailure = "search_result_failure"
    static let paginate = "search_paginate"
}

private enum ParamKey {
    static let query = "query"
    static let count = "count"
    static let reason = "reason"
    static let page = "page"
}

enum SearchAnalyticsEvent: AnalyticsEvent {
    case query(String)
    case resultSuccess(query: String, count: Int)
    case resultFailure(query: String, reason: String)
    case paginate(query: String, page: Int)

    var name: String {
        switch self {
        case .query: return EventName.query
        case .resultSuccess: return EventName.resultSuccess
        case .resultFailure: return EventName.resultFailure
        case .paginate: return EventName.paginate
        }
    }

    var parameters: [String: Any] {
        switch self {
        case .query(let q):
            return [ParamKey.query: q]
        case .resultSuccess(let q, let count):
            return [ParamKey.query: q, ParamKey.count: count]
        case .resultFailure(let q, let reason):
            return [ParamKey.query: q, ParamKey.reason: reason]
        case .paginate(let q, let page):
            return [ParamKey.query: q, ParamKey.page: page]
        }
    }
}
