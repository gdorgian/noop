import Foundation

// NoticeRules.swift — the decisions behind Noop Aura's own notifications, kept pure so they are tested here
// and the app layer only schedules what they say.
//
//  • Bedtime: a nudge before the time that gets the wearer their own sleep need before their usual wake on
//    the next morning, per weekday, learned from their nights.
//  • A new best: last night beat every night of the last ninety on a vital that only moves with fitness and
//    recovery (resting pulse down, HRV up, Charge up).
//  • The week: seven days against the seven before.

public enum NoticeRules {

    // MARK: - Bedtime

    /// One night's end, as the local weekday (1 = Sunday … 7 = Saturday) and minute of the day it ended.
    public struct Wake: Equatable, Sendable {
        public let weekday: Int
        public let minute: Int
        public init(weekday: Int, minute: Int) { self.weekday = weekday; self.minute = minute }
    }

    /// One night for the sleep-need estimate: minutes asleep and the Charge of the morning after.
    public struct Night: Equatable, Sendable {
        public let asleepMinutes: Double
        public let charge: Double?
        public init(asleepMinutes: Double, charge: Double?) { self.asleepMinutes = asleepMinutes; self.charge = charge }
    }

    /// Nights needed before any bedtime is suggested.
    public static let nightsNeeded = 14
    /// Minutes between the nudge and the bedtime it names: time to wind down.
    public static let leadMinutes = 30
    /// Minutes allowed for falling asleep, so "in bed by" leaves the full need asleep.
    public static let fallAsleepMinutes = 15
    /// A Charge at or above this counts as a morning the wearer woke recovered.
    public static let recoveredCharge = 67.0

    /// The wearer's own sleep need in minutes: the median sleep before mornings they woke recovered, from at
    /// least five such mornings, held to 7–9.5 h. Eight hours until then.
    public static func sleepNeed(_ nights: [Night]) -> Int {
        let good = nights.filter { ($0.charge ?? 0) >= recoveredCharge && $0.asleepMinutes >= 180 }
            .map(\.asleepMinutes).sorted()
        guard good.count >= 5 else { return 8 * 60 }
        let median = good[good.count / 2]
        return Int(min(max(median, 7 * 60), 9.5 * 60).rounded())
    }

    /// The usual wake minute for each weekday: that weekday's median from two or more nights, else the median
    /// of all nights. Empty with fewer than `nightsNeeded` nights.
    public static func usualWake(_ wakes: [Wake]) -> [Int: Int] {
        guard wakes.count >= nightsNeeded else { return [:] }
        let all = median(wakes.map(\.minute))
        var out: [Int: Int] = [:]
        for day in 1...7 {
            let own = wakes.filter { $0.weekday == day }.map(\.minute)
            out[day] = own.count >= 2 ? median(own) : all
        }
        return out
    }

    /// For the night before `wakeWeekday`: the bedtime and the nudge, as minutes from that evening's midnight
    /// (so 23:10 is 1390 and 00:20 is 1460). `need` and `wake` in minutes.
    public static func bedtime(wakeMinute: Int, need: Int) -> (bedtime: Int, nudge: Int) {
        let bed = wakeMinute + 24 * 60 - need - fallAsleepMinutes
        return (bed, bed - leadMinutes)
    }

    // MARK: - A new best

    /// The previous best this value beats, or nil when it beats nothing. `prior` holds the earlier days of the
    /// window; at least thirty are needed so a new wearer's second week is not a stream of "bests", and the
    /// value must beat the previous best by `margin` so a tie or rounding never counts.
    public static func previousBest(_ value: Double, prior: [Double], higherIsBetter: Bool,
                                    margin: Double) -> Double? {
        guard prior.count >= 30 else { return nil }
        if higherIsBetter {
            guard let best = prior.max(), value >= best + margin else { return nil }
            return best
        }
        guard let best = prior.min(), value <= best - margin else { return nil }
        return best
    }

    // MARK: - The week

    public struct Week: Equatable, Sendable {
        public let asleepMinutes: Double?
        public let charge: Double?
        public let sessions: Int
        public init(asleepMinutes: Double?, charge: Double?, sessions: Int) {
            self.asleepMinutes = asleepMinutes; self.charge = charge; self.sessions = sessions
        }
    }

    /// Averages over the days that have a value, so a night without the strap does not read as no sleep.
    public static func week(asleep: [Double?], charge: [Double?], sessions: Int) -> Week {
        func mean(_ xs: [Double?]) -> Double? {
            let v = xs.compactMap { $0 }
            return v.isEmpty ? nil : v.reduce(0, +) / Double(v.count)
        }
        return Week(asleepMinutes: mean(asleep), charge: mean(charge), sessions: sessions)
    }

    private static func median(_ xs: [Int]) -> Int {
        let s = xs.sorted()
        return s.isEmpty ? 0 : s[s.count / 2]
    }
}
