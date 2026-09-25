#if os(iOS)
import Foundation
import StrandAnalytics
import WhoopStore

/// Trends' measured record for the production shell: weekly means of the four lines, and the
/// twelve-week attendance grid, straight off the stored daily rows. The verdict wording is chosen
/// by the copy law's gates in `NoopTrendsScreen`, from these same numbers.
struct NoopTrendsRecord: Equatable {
    /// Weekly means, oldest → newest, for the last 52 weeks ending this week. Nil for a week with no value.
    var restingPulse: [Double?] = []
    var variability: [Double?] = []
    /// Hours asleep.
    var sleep: [Double?] = []
    /// ml/kg/min, from the stored VO₂max estimate.
    var capacity: [Double?] = []
    /// The last 84 days, oldest → newest: 0 nothing recorded · 1 slept, worn · 2 moved as well.
    var attendance: [Int] = []
    /// Monday of each week, aligned with the weekly series.
    var weekStarts: [Date] = []
    /// The need every sleep surface measures against (`SleepModel.debtNeedMin`), in minutes.
    var needMin: Double = 0
    /// Weekly mean of how far each night's onset sat from the wearer's own usual onset, in minutes.
    var drift: [Double?] = []
    /// Minutes asleep per recorded night, oldest → newest, for "nights over your need".
    var nights: [Night] = []
    struct Night: Equatable { let day: Date; let minutes: Double }
    var loaded = false

    static let weeks = 52

    static func build(days: [DailyMetric], capacityDays: [(day: String, value: Double)],
                      sessions: [CachedSleepSession] = [],
                      now: Date = Date(), calendar: Calendar = .current) -> NoopTrendsRecord {
        var cal = calendar
        cal.firstWeekday = 2
        let thisWeek = cal.dateInterval(of: .weekOfYear, for: now)?.start ?? cal.startOfDay(for: now)
        let starts: [Date] = (0..<weeks).compactMap {
            cal.date(byAdding: .weekOfYear, value: $0 - (weeks - 1), to: thisWeek)
        }
        let parser = DateFormatter()
        parser.calendar = Calendar(identifier: .gregorian)
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.dateFormat = "yyyy-MM-dd"

        func weekly(_ rows: [(String, Double)]) -> [Double?] {
            var sums = Array(repeating: 0.0, count: weeks), counts = Array(repeating: 0, count: weeks)
            for (key, value) in rows where value.isFinite && value > 0 {
                guard let date = parser.date(from: key), let first = starts.first,
                      date >= first else { continue }
                let index = cal.dateComponents([.weekOfYear], from: first, to: date).weekOfYear ?? -1
                guard (0..<weeks).contains(index) else { continue }
                sums[index] += value; counts[index] += 1
            }
            return (0..<weeks).map { counts[$0] > 0 ? sums[$0] / Double(counts[$0]) : nil }
        }

        var record = NoopTrendsRecord()
        record.weekStarts = starts
        record.restingPulse = weekly(days.compactMap { d in d.restingHr.map { (d.day, Double($0)) } })
        record.variability = weekly(days.compactMap { d in d.avgHrv.map { (d.day, $0) } })
        record.sleep = weekly(days.compactMap { d in d.totalSleepMin.map { (d.day, $0 / 60) } })
        record.capacity = weekly(capacityDays.map { ($0.day, $0.value) })

        let byDay = Dictionary(days.map { ($0.day, $0) }, uniquingKeysWith: { _, last in last })
        let today = cal.startOfDay(for: now)
        record.attendance = (0..<84).map { offset in
            guard let date = cal.date(byAdding: .day, value: offset - 83, to: today),
                  let row = byDay[parser.string(from: date)],
                  (row.totalSleepMin ?? 0) > 0 else { return 0 }
            return (row.exerciseCount ?? 0) > 0 ? 2 : 1
        }
        record.needMin = SleepModel.debtNeedMin(days: days)
        record.nights = days.compactMap { d in
            guard let m = d.totalSleepMin, m > 0, let date = parser.date(from: d.day) else { return nil }
            return Night(day: date, minutes: m)
        }

        // Bedtime drift: each onset's circular distance from the usual onset (the circular mean of
        // every onset in the year), averaged per week.
        let onsets: [(date: Date, minute: Double)] = sessions.map { session in
            let d = Date(timeIntervalSince1970: TimeInterval(session.effectiveStartTs))
            let c = cal.dateComponents([.hour, .minute], from: d)
            return (d, Double((c.hour ?? 0) * 60 + (c.minute ?? 0)))
        }.filter { onset in starts.first.map { onset.date >= $0 } ?? false }
        if !onsets.isEmpty {
            let angles = onsets.map { $0.minute / 1440 * 2 * .pi }
            let usual = atan2(angles.map(sin).reduce(0, +), angles.map(cos).reduce(0, +)) / (2 * .pi) * 1440
            var sums = Array(repeating: 0.0, count: weeks), counts = Array(repeating: 0, count: weeks)
            for onset in onsets {
                guard let first = starts.first,
                      let index = cal.dateComponents([.weekOfYear], from: first, to: onset.date).weekOfYear,
                      (0..<weeks).contains(index) else { continue }
                var diff = abs(onset.minute - usual).truncatingRemainder(dividingBy: 1440)
                if diff > 720 { diff = 1440 - diff }
                sums[index] += diff; counts[index] += 1
            }
            record.drift = (0..<weeks).map { counts[$0] > 0 ? sums[$0] / Double(counts[$0]) : nil }
        } else {
            record.drift = Array(repeating: nil, count: weeks)
        }
        record.loaded = true
        return record
    }
}

@MainActor
final class NoopTrendsStore: ObservableObject {
    @Published private(set) var record = NoopTrendsRecord()

    func load(from repo: Repository) async {
        guard repo.loaded else { return }
        let capacity = await repo.exploreSeries(key: "vo2max_est", source: "my-whoop", days: 400)
        let sessions = await repo.allSleepSessions()
        record = NoopTrendsRecord.build(days: repo.days, capacityDays: capacity,
                                        sessions: sessions.isEmpty ? repo.sleeps : sessions)
    }
}
#endif
