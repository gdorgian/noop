import Foundation

/// Weeks in a row with at least one workout — the streak that rewards showing up, not going hard.
///
/// A week is the calendar's week (its own first weekday). The streak counts back from this week if it
/// already has a workout, otherwise from last week: a week still in progress is not broken until it ends,
/// it is "at risk".
public enum TrainingStreak {

    public struct Reading: Equatable, Sendable {
        /// Consecutive weeks with a workout, up to and including this week when it has one.
        public let weeks: Int
        /// The longest run in the history given.
        public let best: Int
        /// This week already has a workout.
        public let thisWeekDone: Bool
        /// Whole days left in this week, today included — how long a streak at risk has to be kept.
        public let daysLeft: Int
        /// Workouts this week.
        public let thisWeekCount: Int

        /// A streak exists and this week has nothing yet.
        public var atRisk: Bool { weeks > 0 && !thisWeekDone }
    }

    public static func reading(sessionDates: [Date], now: Date, calendar: Calendar = .current) -> Reading {
        guard let thisWeek = calendar.dateInterval(of: .weekOfYear, for: now) else {
            return Reading(weeks: 0, best: 0, thisWeekDone: false, daysLeft: 0, thisWeekCount: 0)
        }
        let past = sessionDates.filter { $0 <= now }
        let starts = Set(past.compactMap { calendar.dateInterval(of: .weekOfYear, for: $0)?.start })
        let thisWeekCount = past.filter { thisWeek.contains($0) }.count
        let done = thisWeekCount > 0

        func previous(_ week: Date) -> Date? { calendar.date(byAdding: .weekOfYear, value: -1, to: week) }

        var weeks = 0
        var cursor: Date? = done ? thisWeek.start : previous(thisWeek.start)
        while let week = cursor, starts.contains(week) {
            weeks += 1
            cursor = previous(week)
        }

        var best = 0, run = 0
        var last: Date?
        for week in starts.sorted() {
            if let last, previous(week) == last { run += 1 } else { run = 1 }
            best = max(best, run)
            last = week
        }

        let today = calendar.startOfDay(for: now)
        let end = calendar.startOfDay(for: thisWeek.end)
        let daysLeft = max(0, calendar.dateComponents([.day], from: today, to: end).day ?? 0)
        return Reading(weeks: weeks, best: max(best, weeks), thisWeekDone: done, daysLeft: daysLeft,
                       thisWeekCount: thisWeekCount)
    }
}
