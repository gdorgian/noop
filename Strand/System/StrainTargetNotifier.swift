import Foundation
import StrandAnalytics
import UserNotifications

// MARK: - Target-strain notification (#593)
//
// A single opt-in, default-OFF celebratory nudge: once per day, when the day's Effort (strain) reaches the
// LOW end of today's recovery-derived OPTIMAL strain band (the #43 coupled read), post an "optimal strain
// reached" notification. Twin of the Android `StrainTargetNotifier`/`StrainTargetPolicy` — the pure policy
// must stay byte-identical (feature-level parity).
//
// CLEAN-ROOM: this reimplements the BEHAVIOUR only. The copy is NOOP's own — NOT WHOOP's decompiled
// strings — and the target is NOOP's own recovery→strain band (#43), not a value read off another app.
//
// The gate runs on the 0-21 coupled axis: the day's stored Effort (0-100) is converted with the shipped
// UnitFormatter.effortValue(_, .whoop) at the call site, and the target is the optimal band's lowerBound
// (already 0-21). It is NOT "the instant" you cross the target — day strain is a per-analytics-pass
// rollup, so it fires on the first pass at/after the crossing. Once-per-day dedupe via a persisted day
// string, the same crossing-dedupe idiom as BatteryNotifier / the Android ScheduledReportPolicy.
enum StrainTargetNotifier {
    private static let lastDayKey = "behavior.strainTargetLastDay"

    /// Pure, testable policy + copy — no notification/UserDefaults runtime, so the decision logic is
    /// pinned by StrainTargetPolicyTests. Byte-identical twin of the Android `StrainTargetPolicy`.
    enum StrainTargetPolicy {
        /// Fire at most once per day: only when enabled, BOTH the day strain and the target are known,
        /// the day strain has reached the target, and we haven't already posted for `today`. `dayStrain`
        /// and `target` must be on the SAME axis (the 0-21 coupled axis, per the call site). A nil
        /// `target` means recovery is unknown (calibrating / unscored) ⇒ no target ⇒ never fires
        /// (never guess a target).
        static func shouldNotify(enabled: Bool,
                                 dayStrain: Double?,
                                 target: Double?,
                                 lastNotifiedDay: String?,
                                 today: String) -> Bool {
            guard enabled, let dayStrain, let target else { return false }
            return dayStrain >= target && lastNotifiedDay != today
        }

        /// Title + body for the nudge. `target` is the optimal-band low on the 0-21 coupled axis.
        /// NOOP's OWN wording — the feature is reimplemented behaviour, not copied copy.
        static func copy(target: Int) -> (title: String, body: String) {
            (String(localized: "Optimal strain reached"),
             String(localized: "You've hit today's optimal strain target of \(target). Nice work — your recovery earned it."))
        }
    }

    /// Noop Aura's own target band on the stored 0–100 Effort axis: easier after a low recovery, harder after
    /// a high one. The Today ring's hatched band and the Aura notice both read it, so the number the
    /// notice names is the band the ring draws. Nil until recovery is scored.
    ///
    /// WHOOP-exact build: with the bundled recovery table this is WHOOP's own target row for the recovery
    /// (lower…upper, interpolated at the recovery percent) mapped 0–21 → 0–100 by the shipped
    /// `effortValue(fromWhoopStrain:)`, so the ring band, the notice and the coupled target all name the
    /// same curve. Without tables: the existing Bevel-port band below.
    static func auraTarget(recovery: Double?) -> ClosedRange<Double>? {
        guard let r = recovery else { return nil }
        if let band = WhoopStrain.targetStrain21(recovery: r)?.band {
            let lower = StrainScorer.effortValue(fromWhoopStrain: band.lowerBound)
            let upper = StrainScorer.effortValue(fromWhoopStrain: band.upperBound)
            return lower...upper
        }
        let mid = 25 + 45 * min(1, max(0, r / 100))
        return (mid - 9)...(mid + 9)
    }

    /// The Aura notice: today's Effort reached the low end of `auraTarget`. Same once-a-day gate and
    /// authorisation idiom as `onDayUpdate`; the copy names Effort on the wearer's chosen scale.
    static func onAuraDayUpdate(day: String, effort: Double?, recovery: Double?, enabled: Bool, scale: EffortScale) {
        let d = UserDefaults.standard
        let low = auraTarget(recovery: recovery)?.lowerBound
        guard StrainTargetPolicy.shouldNotify(enabled: enabled, dayStrain: effort, target: low,
                                              lastNotifiedDay: d.string(forKey: lastDayKey), today: day),
              let low else { return }
        let shown = UnitFormatter.effortDisplay(low, scale: scale)
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else { return }
            let content = UNMutableNotificationContent()
            content.title = String(localized: "Effort target reached")
            content.body = String(localized: "Today's Effort has reached \(shown), the low end of what your recovery allows.")
            content.sound = .default
            center.add(UNNotificationRequest(identifier: "strain-target", content: content, trigger: nil))
            UserDefaults.standard.set(day, forKey: lastDayKey)
        }
    }

    /// Ask up front (called when the user enables the nudge) so the system dialog appears at a
    /// predictable moment, not on the first crossing. BatteryNotifier idiom.
    static func requestAuthorization() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// Run the policy against the resolved today-row's values and post at most one notification per day.
    /// `dayStrain21`/`target21` are on the 0-21 coupled axis (the caller converts the stored 0-100 Effort
    /// via UnitFormatter and reads the target off the #43 optimal band). No-op on every path that fails
    /// the policy, so the caller can fire it freely each time the day history republishes. The persisted
    /// day marker advances only after an authorized post, so a notifications-denied day still notifies
    /// once they're re-enabled while the same day still shows the reached target (Android twin behaviour).
    static func onDayUpdate(day: String, dayStrain21: Double?, target21: Int?, enabled: Bool) {
        let d = UserDefaults.standard
        guard StrainTargetPolicy.shouldNotify(enabled: enabled,
                                              dayStrain: dayStrain21,
                                              target: target21.map(Double.init),
                                              lastNotifiedDay: d.string(forKey: lastDayKey),
                                              today: day) else { return }
        // Non-nil: shouldNotify above required a non-nil target before returning true.
        let copy = StrainTargetPolicy.copy(target: target21!)
        let center = UNUserNotificationCenter.current()
        // Authorization is requested once via requestAuthorization() when the toggle is enabled; here we
        // only check status (no second system prompt) — the BatteryNotifier idiom.
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else { return }
            let content = UNMutableNotificationContent()
            content.title = copy.title
            content.body = copy.body
            content.sound = .default
            center.add(UNNotificationRequest(identifier: "strain-target", content: content, trigger: nil))
            UserDefaults.standard.set(day, forKey: lastDayKey)
        }
    }
}
