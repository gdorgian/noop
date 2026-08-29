import Foundation
import StrandAnalytics

/// Fulfils onboarding's “I would rather not say” promise without asking again. Once enough sleep
/// history exists for Repository's guarded habitual-midsleep calculation, derive the detector's
/// awake band from it and persist the result. Until then the normal day-worker guard remains.
enum NoopScheduleInference {
    /// The explicit night-shift choices are always night-worker layouts. For a schedule learned from
    /// sleep history, an awake band that crosses midnight means the wearer normally sleeps by day.
    static func isNightWorker(kind: String, defaults: UserDefaults = .standard) -> Bool {
        if kind == "permanent-nights" || kind == "rotating" { return true }
        guard kind == "learned",
              let awakeStart = defaults.object(forKey: SleepSchedulePrefs.awakeStartKey) as? Int,
              let awakeEnd = defaults.object(forKey: SleepSchedulePrefs.awakeEndKey) as? Int else {
            return false
        }
        return awakeStart > awakeEnd
    }

    static func applyIfReady(repo: Repository, defaults: UserDefaults = .standard) async {
        guard defaults.bool(forKey: "noop.schedule.inferFromHistory") else { return }
        guard let midsleepSeconds = await repo.habitualMidsleepSec(days: 90) else { return }

        let midpointHour = ((midsleepSeconds / 3_600) % 24 + 24) % 24
        let awakeStart = (midpointHour + 8) % 24
        let awakeEnd = (midpointHour + 20) % 24
        guard awakeStart != awakeEnd else { return }

        await MainActor.run {
            SleepSchedulePrefs.store(SleepSchedule(awakeStartHour: awakeStart, awakeEndHour: awakeEnd), in: defaults)
            defaults.set("learned", forKey: "noop.schedule.kind")
            defaults.set(false, forKey: "noop.schedule.inferFromHistory")
        }
    }
}
