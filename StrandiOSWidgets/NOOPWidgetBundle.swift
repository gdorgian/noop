import WidgetKit
import SwiftUI

/// The widget extension entry point. Bundles the glanceable widget, the three-ring widget, the
/// live-HR Live Activity, the K10 Coach brief widget (stored morning brief on Lock Screen / Home
/// Screen), the heart-rate trace widget (#1957), the stress curve widget (#2040), and the Lift Log
/// session Live Activity.
///
/// `NOOPRingsWidget` arrived complete with the Today redesign and was never registered here, so it
/// has never been installable despite shipping in the binary. It leads on Charge at systemSmall,
/// which the glanceable widget's lock-screen accessory also does; that overlap is deliberate and
/// belongs to the widget gallery's copy, not to this list.
@main
struct NOOPWidgetBundle: WidgetBundle {
    var body: some Widget {
        NOOPWidget()
        NOOPRingsWidget()
        NOOPLiveActivity()
        CoachBriefWidget()
        HeartRateWidget()
        StressWidget()
        LiftLiveActivity()
    }
}
