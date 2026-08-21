import Foundation

// MARK: - The training series WHOOP's own export carries, computed from live data
//
// `WhoopImporter` derives seven metric series from a WHOOP CSV export: per-zone minutes, the zone 1–3
// and 4–5 rollups, total zone minutes, and strength-activity time. They are real, and `MetricCatalog`
// already names them — but they only ever existed for wearers who could still produce an export.
//
// Four of WHOOP Age's nine inputs live in that set (zone 1–3 minutes, zone 4–5 minutes, strength
// minutes, and steps), so a wearer without a subscription had them for their history and nothing for
// this week. Computing them from the workouts NOOP detects itself closes that.
//
// The definitions here are the importer's definitions, deliberately, so an imported day and a computed
// day mean the same thing:
//
//   • Zone minutes are derived from each workout's own zone PERCENTAGES times its duration — not from a
//     fresh pass over the day's heart rate. That is how the importer does it, and mixing the two would
//     produce a series whose meaning changed halfway through its own history.
//   • Strength time matches a workout's sport name against "strength" or "weight", the same substring
//     test the importer applies to WHOOP's `activityName`.
//
// Nothing here scores anything. These are measured series; whether an age model should read them is a
// separate question with a separate evidence bar.

public enum TrainingLoadSeries {

    /// One detected or recorded workout, reduced to what these series need.
    public struct Workout: Equatable, Sendable {
        public let day: String            // YYYY-MM-DD, local
        public let minutes: Double
        public let sport: String
        /// Z1…Z5 percentages (0–100), or nil when the row carries no usable zone data.
        public let zonePercents: [Double]?

        public init(day: String, minutes: Double, sport: String, zonePercents: [Double]?) {
            self.day = day
            self.minutes = minutes
            self.sport = sport
            self.zonePercents = zonePercents
        }
    }

    /// A day's derived training series, keyed exactly as `WhoopImporter` writes them.
    public struct DayTotals: Equatable, Sendable {
        public let day: String
        /// Minutes in each zone, Z1…Z5.
        public let zoneMinutes: [Double]
        public let strengthMinutes: Double

        public var zones13: Double { zoneMinutes.prefix(3).reduce(0, +) }
        public var zones45: Double { zoneMinutes.suffix(2).reduce(0, +) }
        public var zonesAll: Double { zoneMinutes.reduce(0, +) }

        public init(day: String, zoneMinutes: [Double], strengthMinutes: Double) {
            self.day = day
            self.zoneMinutes = zoneMinutes
            self.strengthMinutes = strengthMinutes
        }
    }

    /// Whether a sport name counts as strength work.
    ///
    /// Substring matching rather than an enumerated list, matching the importer. It is loose on purpose:
    /// the sport string can arrive from WHOOP's own naming, NOOP's catalog, or a wearer's own edit, and
    /// an exhaustive list would silently miss "Upper body strength" while a substring test does not.
    public static func isStrength(sport: String) -> Bool {
        let name = sport.lowercased()
        return name.contains("strength") || name.contains("weight")
    }

    /// Fold workouts into per-day totals. Days with no workouts are absent rather than zero — a day the
    /// wearer did not train and a day NOOP did not observe are different facts, and only the second one
    /// should be missing from a series.
    public static func dayTotals(workouts: [Workout]) -> [DayTotals] {
        var zoneByDay: [String: [Double]] = [:]
        var strengthByDay: [String: Double] = [:]

        for workout in workouts where workout.minutes > 0 {
            if let percents = workout.zonePercents, percents.count >= 5 {
                var minutes = zoneByDay[workout.day] ?? [0, 0, 0, 0, 0]
                for zone in 0..<5 {
                    minutes[zone] += workout.minutes * percents[zone] / 100.0
                }
                zoneByDay[workout.day] = minutes
            }
            if isStrength(sport: workout.sport) {
                strengthByDay[workout.day, default: 0] += workout.minutes
            }
        }

        let days = Set(zoneByDay.keys).union(strengthByDay.keys)
        return days.sorted().map { day in
            DayTotals(day: day,
                      zoneMinutes: zoneByDay[day] ?? [0, 0, 0, 0, 0],
                      strengthMinutes: strengthByDay[day] ?? 0)
        }
    }

    /// The metric-series keys and values a day's totals produce, in `WhoopImporter`'s exact spelling.
    ///
    /// A zero total is still written when the day had a workout — "you trained and none of it was
    /// zone 5" is a measurement. A day with no workout produces no `DayTotals` at all, so it never
    /// reaches here.
    public static func seriesPoints(for totals: DayTotals) -> [(key: String, value: Double)] {
        var points: [(key: String, value: Double)] = []
        for (index, minutes) in totals.zoneMinutes.enumerated() {
            points.append((key: "hr_zone\(index + 1)_min", value: minutes))
        }
        points.append((key: "hr_zones13_min", value: totals.zones13))
        points.append((key: "hr_zones45_min", value: totals.zones45))
        points.append((key: "hr_zones_all_min", value: totals.zonesAll))
        if totals.strengthMinutes > 0 {
            points.append((key: "strength_min", value: totals.strengthMinutes))
        }
        return points
    }
}
