//  FirebaseAnalyticsProvider.swift
//
//  Adapter for Firebase Analytics. This is a stub: to go live, add the Firebase
//  SDK + GoogleService-Info.plist, `import FirebaseAnalytics`, and forward to
//  `Analytics.logEvent`. The rest of the app is unaffected.
//

import Foundation

final class FirebaseAnalyticsProvider: AnalyticsProvider {

    let name = "Firebase"

    func record(_ event: AnalyticsEvent) {
        // Real integration would look like:
        //
        //   import FirebaseAnalytics
        //   Analytics.logEvent(event.name, parameters: event.parameters)
        //
        #if DEBUG
        print("[Firebase] \(event.name)  \(event.parameters)")
        #endif
    }
}
