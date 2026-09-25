#if os(iOS)
import Foundation
import WhoopStore

/// The Effort act's measured record for the production shell: the stored sessions (manual, strap,
/// imported and Apple Health rows through `Repository.workoutRows`, already de-duplicated) and the
/// last seven days of Effort. Nothing here prescribes a session or prices one — that engine does not
/// exist — so every screen that draws from this states only what was recorded.
struct NoopEffortRecord {
    /// Every stored session, newest first.
    var workouts: [WorkoutRow] = []
    /// Seven calendar days ending today, oldest → newest: the weekday's short name and its Effort (0–100).
    var week: [(label: String, value: Double?)] = []
    /// The first day anything was recorded, for how far back a range can honestly reach.
    var firstDay: Date?
    var loaded = false

    static func build(days: [DailyMetric], workouts: [WorkoutRow], now: Date = Date(),
                      calendar: Calendar = .current) -> NoopEffortRecord {
        var record = NoopEffortRecord()
        record.workouts = workouts.sorted { $0.startTs > $1.startTs }
        let byDay = Dictionary(days.map { ($0.day, $0) }, uniquingKeysWith: { _, last in last })
        let today = calendar.startOfDay(for: now)
        let weekday = DateFormatter()
        weekday.setLocalizedDateFormatFromTemplate("EEE")
        record.week = (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset - 6, to: today) else { return nil }
            return (weekday.string(from: date), byDay[Repository.localDayKey(date)]?.strain)
        }
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.dateFormat = "yyyy-MM-dd"
        let firstMetric = days.compactMap { parser.date(from: $0.day) }.min()
        let firstWorkout = workouts.map { Date(timeIntervalSince1970: TimeInterval($0.startTs)) }.min()
        record.firstDay = [firstMetric, firstWorkout].compactMap { $0 }.min()
        record.loaded = true
        return record
    }

    /// Whole days from the first record to today, inclusive; 0 with nothing recorded.
    func historyDays(now: Date = Date(), calendar: Calendar = .current) -> Int {
        guard let firstDay else { return 0 }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: firstDay),
                                           to: calendar.startOfDay(for: now)).day ?? 0
        return max(1, days + 1)
    }

    /// Sessions that started within the last `days` calendar days, today included.
    func sessions(inLast days: Int, now: Date = Date(), calendar: Calendar = .current) -> [WorkoutRow] {
        guard let start = calendar.date(byAdding: .day, value: -(days - 1), to: calendar.startOfDay(for: now)) else {
            return workouts
        }
        let from = Int(start.timeIntervalSince1970)
        return workouts.filter { $0.startTs >= from }
    }
}

extension WorkoutRow {
    /// Moving minutes, from the stored duration (pauses already taken off) or the start/end span.
    var noopMinutes: Int {
        let seconds = durationS ?? Double(endTs - startTs)
        return max(0, Int((seconds / 60).rounded()))
    }

    /// Where the row came from, in the design's three words.
    var noopSourceLabel: String {
        let s = source.lowercased()
        if s.contains("apple") || s.contains("health") { return "Health" }
        if s.contains("import") || s.contains("csv") || s.contains("whoop") || s.contains("strava")
            || s.contains("fit") || s.contains("gpx") { return "imported" }
        return "strap"
    }
}

@MainActor
final class NoopEffortStore: ObservableObject {
    @Published private(set) var record = NoopEffortRecord()

    func load(from repo: Repository) async {
        guard repo.loaded else { return }
        let rows = await repo.workoutRows(days: 4000)
        record = NoopEffortRecord.build(days: repo.days, workouts: rows)
    }
}
#endif
