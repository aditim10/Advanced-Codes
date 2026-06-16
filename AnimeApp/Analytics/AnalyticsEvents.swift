//  AnalyticsEvents.swift
//
//  Concrete analytics events, grouped by feature. Each enum conforms to
//  `AnalyticsEvent` and maps its cases to a stable name + payload. To add a new
//  event, add a case here — nothing else in the pipeline needs to change.

import Foundation

// MARK: - App lifecycle

enum AppLifecycleEvent: AnalyticsEvent {
    /// Fired once when the app finishes launching.
    case appLaunch

    var name: String {
        switch self {
        case .appLaunch: return "app_launch"
        }
    }
}

// MARK: - Login

enum LoginAnalyticsEvent: AnalyticsEvent {
    case attempt(email: String)
    case invalidCredentials(reason: String)
    case success(email: String)
    case failure(reason: String)

    var name: String {
        switch self {
        case .attempt: return "login_attempt"
        case .invalidCredentials: return "login_invalid_credentials"
        case .success: return "login_success"
        case .failure: return "login_failure"
        }
    }

    var parameters: [String: Any] {
        switch self {
        case .attempt(let email): return ["email": email]
        case .invalidCredentials(let reason): return ["reason": reason]
        case .success(let email): return ["email": email]
        case .failure(let reason): return ["reason": reason]
        }
    }
}

// MARK: - Home

enum HomeAnalyticsEvent: AnalyticsEvent {
    /// Home finished its initial load successfully.
    case loadSuccess(sectionCount: Int)
    case loadFailure(reason: String)
    /// User scrolled near the bottom and a new page/section was requested.
    case paginate(page: Int)

    var name: String {
        switch self {
        case .loadSuccess: return "home_load_success"
        case .loadFailure: return "home_load_failure"
        case .paginate: return "home_paginate"
        }
    }

    var parameters: [String: Any] {
        switch self {
        case .loadSuccess(let count): return ["section_count": count]
        case .loadFailure(let reason): return ["reason": reason]
        case .paginate(let page): return ["page": page]
        }
    }
}

// MARK: - Search

enum SearchAnalyticsEvent: AnalyticsEvent {
    case query(String)
    case resultSuccess(query: String, count: Int)
    case resultFailure(query: String, reason: String)
    case paginate(query: String, page: Int)

    var name: String {
        switch self {
        case .query: return "search_query"
        case .resultSuccess: return "search_result_success"
        case .resultFailure: return "search_result_failure"
        case .paginate: return "search_paginate"
        }
    }

    var parameters: [String: Any] {
        switch self {
        case .query(let q):
            return ["query": q]
        case .resultSuccess(let q, let count):
            return ["query": q, "count": count]
        case .resultFailure(let q, let reason):
            return ["query": q, "reason": reason]
        case .paginate(let q, let page):
            return ["query": q, "page": page]
        }
    }
}

// MARK: - See all

enum SeeAllAnalyticsEvent: AnalyticsEvent {
    case open(section: String)
    case paginate(section: String, page: Int)

    var name: String {
        switch self {
        case .open: return "see_all_open"
        case .paginate: return "see_all_paginate"
        }
    }

    var parameters: [String: Any] {
        switch self {
        case .open(let section):
            return ["section": section]
        case .paginate(let section, let page):
            return ["section": section, "page": page]
        }
    }
}
