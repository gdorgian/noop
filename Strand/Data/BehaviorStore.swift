import Foundation
import Combine
import StrandAnalytics

enum HRCeilingThresholdMode: String, CaseIterable {
    case zone, bpm
}

enum HRCeilingScope: String, CaseIterable {
    case always, workout
}

/// Settings for the strap's physical inputs and the Mac/coaching automations built on top of the
/// live event + biometric stream. UserDefaults-backed (single-user, on-device).
@MainActor
final class BehaviorStore: ObservableObject {

    // MARK: Double-tap → Mac action
    @Published var doubleTapAction: MacActionKind { didSet { d.set(doubleTapAction.rawValue, forKey: K.dtAction) } }
    @Published var doubleTapShortcut: String { didSet { d.set(doubleTapShortcut, forKey: K.dtShortcut) } }

    // MARK: Wear automation
    /// Lock the Mac when the strap comes off the wrist.
    @Published var autoLockOnWristOff: Bool { didSet { d.set(autoLockOnWristOff, forKey: K.autoLock) } }
    /// Run a Shortcut when the strap comes off (presence automation: Focus, pause media, set away…).
    @Published var wristOffShortcut: String { didSet { d.set(wristOffShortcut, forKey: K.wristOffShortcut) } }
    /// Run a Shortcut when the strap goes back on the wrist.
    @Published var wristOnShortcut: String { didSet { d.set(wristOnShortcut, forKey: K.wristOnShortcut) } }

    // MARK: Configurable heart-rate ceiling haptics
    @Published var zoneCoaching: Bool { didSet { d.set(zoneCoaching, forKey: K.zoneCoaching) } }
    /// Whether the ceiling follows the profile's resolved zone bands or a standalone absolute value.
    @Published var hrCeilingThresholdMode: HRCeilingThresholdMode {
        didSet { d.set(hrCeilingThresholdMode.rawValue, forKey: K.hrCeilingThresholdMode) }
    }
    /// Highest allowed profile zone (1...4). The warning starts at the lower edge of the next zone.
    @Published var hrCeilingAllowedZone: Int {
        didSet { d.set(min(max(hrCeilingAllowedZone, 1), 4), forKey: K.hrCeilingAllowedZone) }
    }
    /// Standalone ceiling used in `.bpm` mode, independent of HRmax and the profile's zone bands.
    @Published var hrCeilingBPM: Int {
        didSet { d.set(min(max(hrCeilingBPM, 40), 220), forKey: K.hrCeilingBPM) }
    }
    /// Always while worn/connected, or only while NOOP is actively recording a workout/session.
    @Published var hrCeilingScope: HRCeilingScope {
        didSet { d.set(hrCeilingScope.rawValue, forKey: K.hrCeilingScope) }
    }
    /// Standard limited reminders, or one warning pulse every two seconds while currently above.
    @Published var hrCeilingReminderMode: HRCeilingReminderMode {
        didSet { d.set(hrCeilingReminderMode.rawValue, forKey: K.hrCeilingReminderMode) }
    }

    // MARK: Haptic biofeedback — Stress check-ins (L3)
    //
    // The v5 "stress check-ins (haptic)" master toggle + sub-toggles. Default OFF (opt-in, manual-first).
    // These MIRROR the keys `BiofeedbackPrefs` reads/writes (the controller + central L3 hook use that
    // value type); exposing them here gives the Settings group an `@Published` binding without a second
    // source of truth — the keys are identical, so a write through either path is seen by both. The
    // central L3 hook (Wave 3) reads `BiofeedbackPrefs.stressConfig()`.
    @Published var stressCheckIn: Bool { didSet { d.set(stressCheckIn, forKey: K.stressCheckIn) } }
    @Published var stressAutoNudge: Bool { didSet { d.set(stressAutoNudge, forKey: K.stressAutoNudge) } }
    @Published var stressQuietHours: Bool { didSet { d.set(stressQuietHours, forKey: K.stressQuietHours) } }
    @Published var stressUseResonancePace: Bool { didSet { d.set(stressUseResonancePace, forKey: K.stressUseResonance) } }

    // MARK: Smart alarm
    @Published var smartAlarmEnabled: Bool { didSet { d.set(smartAlarmEnabled, forKey: K.alarmOn) } }
    /// Target wake time, minutes since local midnight.
    @Published var smartAlarmMinutes: Int { didSet { d.set(smartAlarmMinutes, forKey: K.alarmTime) } }
    /// Weekdays the alarm fires on (Calendar weekday numbers: 1 = Sun … 7 = Sat). An empty set means
    /// "every day" — the backward-compatible default for anyone upgrading from before per-day scheduling.
    @Published var smartAlarmWeekdays: Set<Int> { didSet { d.set(Array(smartAlarmWeekdays).sorted(), forKey: K.alarmWeekdays) } }

    // MARK: Wake window (smart wake; opt-in, experimental)
    //
    // The light-sleep early-wake sweep (`WakeWindow`, `AppModel.wakeWindowTick`): in the last
    // `wakeWindowMinutes` before the wake time the app watches the HR pattern and fires a gentle
    // strap buzz EARLY when it looks wakeable. The firmware alarm itself stays at the full wake
    // time (the window end) — the window can only move waking earlier, never later. The decision
    // heuristic is NOOP's own and TRIAL-TUNABLE (see WakeWindow.swift); default OFF like every
    // other automation. (The retired "behavior.smartAlarmWindow" key above predates this real one.)
    @Published var wakeWindowEnabled: Bool { didSet { d.set(wakeWindowEnabled, forKey: K.wakeWindowOn) } }
    /// Length of the early-wake window in minutes, clamped [5, 90] on read and write.
    @Published var wakeWindowMinutes: Int { didSet { d.set(wakeWindowMinutes, forKey: K.wakeWindowMinutes) } }

    // MARK: Illness early-warning
    @Published var illnessWatch: Bool { didSet { d.set(illnessWatch, forKey: K.illness) } }

    // MARK: Strap battery alerts
    /// Notify on low strap battery (≤15%) and full charge (100%). Default ON (#368).
    @Published var batteryAlerts: Bool { didSet { d.set(batteryAlerts, forKey: K.batteryAlerts) } }
    /// Predictive "recharge tonight" warning at ~24h of estimated runtime left. Sub-gate under
    /// batteryAlerts (both must be on). Default ON so pre-toggle behavior is unchanged.
    @Published var batteryPredictiveAlerts: Bool { didSet { d.set(batteryPredictiveAlerts, forKey: K.batteryPredictiveAlerts) } }

    // MARK: Off-wrist reminder
    /// One notification when the strap has been off the wrist for ten minutes. Default ON.
    @Published var wearAlerts: Bool { didSet { d.set(wearAlerts, forKey: K.wearAlerts) } }

    // MARK: Strain target nudge (#593)
    /// Once-a-day "optimal strain reached" nudge when the day's Effort hits the low end of today's
    /// recovery-derived optimal band. Default OFF like every other automation.
    @Published var strainTargetNudge: Bool { didSet { d.set(strainTargetNudge, forKey: K.strainTargetNudge) } }

    // MARK: Sync reminder (iOS)
    /// A quiet notification when Noop hasn't synced the strap for three hours (`SyncReminderPolicy`). Default
    /// ON: it is passive (no sound, no screen wake) and it guards the one failure the wearer can't see.
    @Published var syncReminder: Bool { didSet { d.set(syncReminder, forKey: K.syncReminder) } }

    private let d: UserDefaults
    private enum K {
        static let dtAction = "behavior.doubleTapAction"
        static let dtShortcut = "behavior.doubleTapShortcut"
        static let autoLock = "behavior.autoLockOnWristOff"
        static let wristOffShortcut = "behavior.wristOffShortcut"
        static let wristOnShortcut = "behavior.wristOnShortcut"
        static let zoneCoaching = "behavior.zoneCoaching"
        static let hrCeilingThresholdMode = "behavior.hrCeilingThresholdMode"
        static let hrCeilingAllowedZone = "behavior.hrCeilingAllowedZone"
        static let hrCeilingBPM = "behavior.hrCeilingBPM"
        static let hrCeilingScope = "behavior.hrCeilingScope"
        static let hrCeilingReminderMode = "behavior.hrCeilingReminderMode"
        // Haptic biofeedback L3 — keys MATCH BiofeedbackPrefs (one source of truth, two readers).
        static let stressCheckIn = "biofeedback.stressCheckIn"
        static let stressAutoNudge = "biofeedback.stressAutoNudge"
        static let stressQuietHours = "biofeedback.stressQuietHours"
        static let stressUseResonance = "biofeedback.stressUseResonancePace"
        static let alarmOn = "behavior.smartAlarmEnabled"
        static let alarmTime = "behavior.smartAlarmMinutes"
        static let alarmWeekdays = "behavior.smartAlarmWeekdays"
        // "behavior.smartAlarmWindow" retired: it was stored but never read (no wake-window
        // watcher ever shipped). The defaults key is left orphaned on purpose — harmless, and
        // preserved should a real light-sleep watcher ever land. It has now: the ACTIVE keys are
        // wakeWindowEnabled / wakeWindowMinutes below, not this retired one.
        static let wakeWindowOn = "behavior.wakeWindowEnabled"
        static let wakeWindowMinutes = "behavior.wakeWindowMinutes"
        static let illness = "behavior.illnessWatch"
        static let batteryAlerts = "behavior.batteryAlerts"
        static let wearAlerts = "behavior.wearAlerts"
        static let batteryPredictiveAlerts = "behavior.batteryPredictiveAlerts"
        static let strainTargetNudge = "behavior.strainTargetNudge"
        static let syncReminder = "behavior.syncReminder"
    }

    init(defaults: UserDefaults = .standard) {
        d = defaults
        doubleTapAction = MacActionKind(rawValue: d.string(forKey: K.dtAction) ?? "") ?? .none
        doubleTapShortcut = d.string(forKey: K.dtShortcut) ?? ""
        autoLockOnWristOff = d.object(forKey: K.autoLock) as? Bool ?? false
        wristOffShortcut = d.string(forKey: K.wristOffShortcut) ?? ""
        wristOnShortcut = d.string(forKey: K.wristOnShortcut) ?? ""
        zoneCoaching = d.object(forKey: K.zoneCoaching) as? Bool ?? false
        hrCeilingThresholdMode = HRCeilingThresholdMode(
            rawValue: d.string(forKey: K.hrCeilingThresholdMode) ?? "") ?? .zone
        hrCeilingAllowedZone = min(max(d.object(forKey: K.hrCeilingAllowedZone) as? Int ?? 4, 1), 4)
        hrCeilingBPM = min(max(d.object(forKey: K.hrCeilingBPM) as? Int ?? 150, 40), 220)
        hrCeilingScope = HRCeilingScope(rawValue: d.string(forKey: K.hrCeilingScope) ?? "") ?? .always
        hrCeilingReminderMode = HRCeilingReminderMode(
            rawValue: d.string(forKey: K.hrCeilingReminderMode) ?? "") ?? .standard
        stressCheckIn = d.object(forKey: K.stressCheckIn) as? Bool ?? false
        stressAutoNudge = d.object(forKey: K.stressAutoNudge) as? Bool ?? false
        stressQuietHours = d.object(forKey: K.stressQuietHours) as? Bool ?? true
        stressUseResonancePace = d.object(forKey: K.stressUseResonance) as? Bool ?? true
        smartAlarmEnabled = d.object(forKey: K.alarmOn) as? Bool ?? false
        smartAlarmMinutes = d.object(forKey: K.alarmTime) as? Int ?? 7 * 60       // 07:00
        // Stored as a plain [Int]; only valid weekday numbers (1…7) are kept so a corrupted defaults
        // entry can never schedule against a bogus day. Empty (or all 7) = every day.
        smartAlarmWeekdays = Set((d.array(forKey: K.alarmWeekdays) as? [Int] ?? []).filter { (1...7).contains($0) })
        wakeWindowEnabled = d.object(forKey: K.wakeWindowOn) as? Bool ?? false
        wakeWindowMinutes = min(max(d.object(forKey: K.wakeWindowMinutes) as? Int ?? 30,
                                    WakeWindow.minWindowMinutes), WakeWindow.maxWindowMinutes)
        illnessWatch = d.object(forKey: K.illness) as? Bool ?? false
        batteryAlerts = d.object(forKey: K.batteryAlerts) as? Bool ?? true
        // Noop Aura starts calm (26 Oct 2026): the off-wrist notice is one a wearer asks for. macOS keeps its default.
        #if os(iOS)
        wearAlerts = d.object(forKey: K.wearAlerts) as? Bool ?? false
        #else
        wearAlerts = d.object(forKey: K.wearAlerts) as? Bool ?? true
        #endif
        batteryPredictiveAlerts = d.object(forKey: K.batteryPredictiveAlerts) as? Bool ?? true
        strainTargetNudge = d.object(forKey: K.strainTargetNudge) as? Bool ?? false
        syncReminder = d.object(forKey: K.syncReminder) as? Bool ?? true
    }

    // MARK: Charge baseline recalibration

    /// Epoch SECONDS the Charge build-up was last manually reset from, or 0 if never. Reads the SAME
    /// canonical key the analytics engine folds against (`Baselines.recoveryBaselineEpochKey`) — no
    /// second source of truth. The "Recalibrate Charge baseline" Settings button writes it (and the
    /// sibling HRV epoch) via `recalibrateChargeBaseline()`.
    var chargeBaselineEpoch: Double { Baselines.recoveryBaselineEpoch(d) }

    /// True once the user has manually recalibrated their Charge baseline. Lets a surface (e.g. the
    /// Today "building" hint) explain WHY the score is calibrating again — an honest "you reset it",
    /// not a silent cold-start.
    var didRecalibrateCharge: Bool { chargeBaselineEpoch > 0 }

    /// Restart the ~4-night Charge build-up from `now`: re-anchor every baseline that feeds Charge
    /// (HRV plus resting HR / respiration / skin temp) WITHOUT deleting any stored day. Delegates to
    /// the single cross-platform source of truth so iOS, macOS and the Android twin stay in lockstep.
    /// After calling this the next baseline computation re-seeds from tonight, so Today honestly shows
    /// the calibrating/building state again. The caller is responsible for kicking a recompute + refresh.
    func recalibrateChargeBaseline(now: Double = Date().timeIntervalSince1970) {
        Baselines.recalibrateRecoveryBaselines(now: now, defaults: d)
    }
}
