//  AmexPanelAnalyticsProvider.swift
//
//  Adapter for an "AmexPanel" analytics back-end. This is a stub: to go live,
//  add the AmexPanel SDK and replace the body of `record(_:)` with the real call.
//  Nothing else in the app changes — this is exactly the flexibility the bus
//  is designed for.
//

import Foundation

final class AmexPanelAnalyticsProvider: AnalyticsProvider {

    let name = "AmexPanel"

    func record(_ event: AnalyticsEvent) {
        // Real integration would look like:
        //
        //   AmexPanel.shared.logEvent(event.name, properties: event.parameters)
        //
        #if DEBUG
        print("[AmexPanel] \(event.name)  \(event.parameters)")
        #endif
    }
}
