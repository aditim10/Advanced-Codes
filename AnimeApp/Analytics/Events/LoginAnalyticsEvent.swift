//  LoginAnalyticsEvent.swift
//
//  Analytics events for the Login flow.
//
//  Privacy note (GDPR / vendor T&Cs): we must not hand raw PII such as the
//  user's email to third-party analytics tools. Identifying cases therefore carry
//  an anonymous `userID` (see `Session.analyticsUserID`) instead of the email.

import Foundation
import AnalyticsKit

private enum EventName {
    static let attempt = "login_attempt"
    static let invalidCredentials = "login_invalid_credentials"
    static let success = "login_success"
    static let failure = "login_failure"
}

private enum ParamKey {
    static let userID = "user_id"
    static let reason = "reason"
}

enum LoginAnalyticsEvent: AnalyticsEvent {
    case attempt(userID: String)
    case invalidCredentials(reason: String)
    case success(userID: String)
    case failure(reason: String)

    var name: String {
        switch self {
        case .attempt: return EventName.attempt
        case .invalidCredentials: return EventName.invalidCredentials
        case .success: return EventName.success
        case .failure: return EventName.failure
        }
    }

    var parameters: [String: Any] {
        switch self {
        case .attempt(let userID): return [ParamKey.userID: userID]
        case .invalidCredentials(let reason): return [ParamKey.reason: reason]
        case .success(let userID): return [ParamKey.userID: userID]
        case .failure(let reason): return [ParamKey.reason: reason]
        }
    }
}
