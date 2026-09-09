import WidgetKit
import SwiftUI
import StrandDesign

/// The widget extension entry point. Bundles the glanceable widget, the three-rings widget (redesign §9),
/// and the live-HR Live Activity.
@main
struct NOOPWidgetBundle: WidgetBundle {
    init() {
        // Widget extensions run in a separate process, so app-side registration does not carry over.
        NoopSpecType.registerFonts()
    }

    var body: some Widget {
        NOOPWidget()
        NOOPRingsWidget()
        NOOPLiveActivity()
    }
}
