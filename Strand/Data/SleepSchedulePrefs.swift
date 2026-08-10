import Foundation
import StrandAnalytics

/// Host-side seed for `SleepAnalytics`' `SleepSchedule` — when the wearer is normally AWAKE.
///
/// The analytics package deliberately knows nothing about `UserDefaults` (it is pure and must run in
/// `swift test` with no app), so the schedule is a value the host sets ONCE at launch, before anything
/// stages a night. This is that seam.
///
/// Resolution order:
/// 1. The two stored hours, when the wearer has set them.
/// 2. `fallback` otherwise.
///
/// `SleepSchedule`'s own initialiser rejects out-of-range or degenerate values and falls back to
/// `.dayWorker`, so a corrupt default cannot produce a band predicate that silently matches nothing.
enum SleepSchedulePrefs {

    static let awakeStartKey = "noop.sleepSchedule.awakeStartHour"
    static let awakeEndKey = "noop.sleepSchedule.awakeEndHour"

    /// FORK-LOCAL: this wearer works nights and sleeps roughly 10:00–19:00 local, so they are awake
    /// 19:00 → 10:00. Upstream would seed `.dayWorker` here and let a Settings screen write the two keys.
    ///
    /// Seeding it in the HOST rather than changing the package default is what keeps the analytics
    /// package byte-identical to upstream — all 1310 of its tests pass untouched — while this build
    /// still stages the wearer's real sleep correctly.
    static let fallback = SleepSchedule(awakeStartHour: 19, awakeEndHour: 10)

    /// Read the stored schedule (or the fallback) and install it. Idempotent; call once per launch
    /// before any analysis runs.
    static func apply(_ defaults: UserDefaults = .standard) {
        SleepSchedule.current = resolve(defaults)
    }

    /// Pure resolution, so the precedence is testable without touching the global.
    static func resolve(_ defaults: UserDefaults) -> SleepSchedule {
        // `object(forKey:)` rather than `integer(forKey:)`: the latter cannot distinguish "unset" from
        // a stored 0, and 0 is a legitimate hour (a wearer awake from midnight).
        guard let start = defaults.object(forKey: awakeStartKey) as? Int,
              let end = defaults.object(forKey: awakeEndKey) as? Int else {
            return fallback
        }
        return SleepSchedule(awakeStartHour: start, awakeEndHour: end)
    }

    /// Persist a schedule chosen by the wearer and install it immediately, so the next analysis pass
    /// uses it without waiting for a relaunch.
    static func store(_ schedule: SleepSchedule, in defaults: UserDefaults = .standard) {
        defaults.set(schedule.awakeStartHour, forKey: awakeStartKey)
        defaults.set(schedule.awakeEndHour, forKey: awakeEndKey)
        SleepSchedule.current = schedule
    }
}
