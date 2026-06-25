//  MixPanelAnalyticsProvider.swift
//
//  Adapter for the Mixpanel analytics back-end. This is a stub: to go live,
//  add the Mixpanel SDK and replace the body of `record(_:)` with the real call.
//  Nothing else in the app changes — this is exactly the flexibility the bus
//  is designed for.
//

import Foundation
import AnalyticsKit

final class MixPanelAnalyticsProvider: AnalyticsProvider {

    let name = "MixPanel"

    func record(_ event: AnalyticsEvent) {
        // Real integration would look like:
        //
        //   Mixpanel.mainInstance().track(event: event.name, properties: event.parameters)
        //
        #if DEBUG
        print("[MixPanel] \(event.name)  \(event.parameters)")
        #endif
    }
}
