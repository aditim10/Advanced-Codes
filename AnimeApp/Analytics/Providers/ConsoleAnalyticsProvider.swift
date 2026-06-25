//  ConsoleAnalyticsProvider.swift
//
//  The simplest possible provider: logs every event to the Xcode console. Always
//  registered so you can see the analytics stream while developing.
//

import Foundation
import AnalyticsKit

final class ConsoleAnalyticsProvider: AnalyticsProvider {

    let name = "Console"

    func record(_ event: AnalyticsEvent) {
        let payload = event.parameters.isEmpty ? "" : "  \(event.parameters)"
        print("[Analytics] \(event.name)\(payload)")
    }
}
