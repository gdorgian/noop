#if os(iOS)
import Foundation
import AppIntents

/// Queue of actions requested by an App Intent while the app may be suspended. Intents can't reach
/// into the running `AppModel` directly (BLE only lives in the foreground app), so they enqueue here
/// and the app drains the queue when it next becomes active.
enum PendingIntents {
    enum Action: String { case markMoment, buzz, exportHealth, confirmHealthExport }

    private static let key = "noop.pendingIntents"
    private static var defaults: UserDefaults? { UserDefaults(suiteName: WidgetSnapshot.suiteName) }

    /// Optional `at` is the invocation time, captured now and consumed on drain. Encoded into the
    /// stored string as "rawValue:epochSeconds" so the array stays a plain [String] (no schema
    /// migration; a legacy bare "markMoment" still decodes with a nil date).
    static func append(_ action: Action, at date: Date? = nil) {
        guard let d = defaults else { return }
        var list = d.stringArray(forKey: key) ?? []
        if let date { list.append("\(action.rawValue):\(date.timeIntervalSince1970)") }
        else { list.append(action.rawValue) }
        d.set(list, forKey: key)
    }

    static func drain() -> [(action: Action, date: Date?)] {
        guard let d = defaults else { return [] }
        let raw = d.stringArray(forKey: key) ?? []
        d.removeObject(forKey: key)
        return raw.compactMap { entry in
            // Guard `parts.first` rather than subscripting `parts[0]`: split(omittingEmptySubsequences:
            // true by default) returns an EMPTY array for an empty or ":"-leading entry, and indexing
            // [0] there is a fatal trap. This value comes from shared App Group defaults read untrusted,
            // so a corrupt/foreign entry must be skipped, not crash the app on foreground.
            let parts = entry.split(separator: ":", maxSplits: 1)
            guard let first = parts.first, let action = Action(rawValue: String(first)) else { return nil }
            let date = parts.count == 2 ? Double(parts[1]).map { Date(timeIntervalSince1970: $0) } : nil
            return (action, date)
        }
    }
}

/// Record a timestamped "moment" — the iOS analogue of the strap double-tap "mark a moment" action.
struct MarkMomentIntent: AppIntent {
    static var title: LocalizedStringResource = "Mark a Moment"
    static var description = IntentDescription("Record a timestamped moment in NOOP.")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        PendingIntents.append(.markMoment, at: Date())
        return .result(dialog: "Moment marked.")
    }
}

/// Send a confirming haptic buzz to the strap. Opens the app so the live BLE link can deliver it.
struct BuzzStrapIntent: AppIntent {
    static var title: LocalizedStringResource = "Buzz Strap"
    static var description = IntentDescription("Send a haptic buzz to your WHOOP strap.")
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        PendingIntents.append(.buzz)
        return .result()
    }
}

/// Rewrite the Shortcuts drop files (`noop_sync.txt`, `noop_sleep.txt`, `noop_workouts.txt`) on demand,
/// so a Shortcut can refresh them and read them back in a single automation.
///
/// Without this the files only refresh when the app moves to the BACKGROUND, which couples export to app
/// usage: go a day without opening NOOP and a time-based automation reads a stale (or, once the watermark
/// has truncated it, empty) file. The offload-landed hook in `StrandiOSApp` covers the common case; this
/// covers "give me everything up to now, right now".
///
/// `openAppWhenRun` because the export reads the on-device store through the app's `Repository`, which
/// only exists in the app process — the same reason `BuzzStrapIntent` opens the app for BLE. It respects
/// the Shortcuts Export opt-in: with the toggle off this writes nothing.
struct RefreshHealthExportIntent: AppIntent {
    static var title: LocalizedStringResource = "Refresh Health Export"
    static var description = IntentDescription(
        "Update NOOP's Shortcuts export files with any new heart rate, HRV, steps, sleep and workouts.")
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        PendingIntents.append(.exportHealth)
        return .result()
    }
}

/// Tell NOOP the Shortcut has finished logging the current drop files into Apple Health, so their rows
/// can be dropped exactly once.
///
/// This is the other half of the accumulate-until-consumed contract: writes only ever mark rows PENDING,
/// and nothing is discarded until this runs. A Shortcut that reads the files but never confirms simply
/// sees the same rows again next time — annoying, but never lossy. Put it as the LAST step of the
/// Shortcut, after the logging loops.
struct ConfirmHealthExportIntent: AppIntent {
    static var title: LocalizedStringResource = "Confirm Health Export"
    static var description = IntentDescription(
        "Tell NOOP the exported rows have been logged, so it can move on to newer data.")
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        PendingIntents.append(.confirmHealthExport)
        return .result()
    }
}

/// Surfaces NOOP's intents to Siri, Spotlight, and the Shortcuts gallery without any user setup.
struct NOOPShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: MarkMomentIntent(),
                    phrases: ["Mark a moment in \(.applicationName)"],
                    shortTitle: "Mark a Moment",
                    systemImageName: "mappin.and.ellipse")
        AppShortcut(intent: BuzzStrapIntent(),
                    phrases: ["Buzz my \(.applicationName) strap"],
                    shortTitle: "Buzz Strap",
                    systemImageName: "waveform.path")
        AppShortcut(intent: RefreshHealthExportIntent(),
                    phrases: ["Refresh my \(.applicationName) health export"],
                    shortTitle: "Refresh Health Export",
                    systemImageName: "square.and.arrow.up.on.square")
        AppShortcut(intent: ConfirmHealthExportIntent(),
                    phrases: ["Confirm my \(.applicationName) health export"],
                    shortTitle: "Confirm Health Export",
                    systemImageName: "checkmark.circle")
    }
}
#endif
