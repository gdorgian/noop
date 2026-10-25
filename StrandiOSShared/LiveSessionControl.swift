#if os(iOS)
import Foundation
import AppIntents

/// The bridge between the Live Activity's Pause/Resume button and the recorder.
///
/// The intent is compiled into the widget extension so the button can name it, but iOS runs a
/// `LiveActivityIntent` in the app's process, where the shell has registered `togglePause`. Nothing
/// here can finish a session: ending goes through the live screen and its confirmation.
public enum LiveSessionControl {
    @MainActor public static var togglePause: (() -> Void)?
    /// The lift banner's rest buttons: add seconds to the running rest, or end it now.
    @MainActor public static var adjustLiftRest: ((Int) -> Void)?
    @MainActor public static var skipLiftRest: (() -> Void)?
}

/// "+30 s" on the lift banner while a rest runs.
struct AddLiftRestIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Add 30 seconds to the rest"
    static let isDiscoverable = false

    func perform() async throws -> some IntentResult {
        await MainActor.run { LiveSessionControl.adjustLiftRest?(30) }
        return .result()
    }
}

/// "Skip" on the lift banner: the rest ends now and the next set is ready.
struct SkipLiftRestIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "End the rest now"
    static let isDiscoverable = false

    func perform() async throws -> some IntentResult {
        await MainActor.run { LiveSessionControl.skipLiftRest?() }
        return .result()
    }
}

/// End…: opens the app on the live screen, whose confirmation finishes the session. An intent rather than a
/// `Link`, because on the Lock Screen a link inside a Live Activity was delivered to the neighbouring
/// button's intent instead (simulator, 25 Oct 2026): End… resumed a paused run and opened nothing.
struct OpenLiveSessionIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Open the running session"
    static let isDiscoverable = false
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            NotificationCenter.default.post(name: .noopOpenWidgetLink, object: WidgetLink.liveSession.url)
        }
        return .result()
    }
}

struct ToggleLiveSessionPauseIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Pause or resume the session"
    static let description = IntentDescription("Pauses the running session, or resumes a paused one.")
    static let isDiscoverable = false

    func perform() async throws -> some IntentResult {
        await MainActor.run { LiveSessionControl.togglePause?() }
        return .result()
    }
}
#endif
