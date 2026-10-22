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
    var throughDay: Date?
    var loaded = false

    static let weeks = 52

    static func build(days: [DailyMetric], capacityDays: [(day: String, value: Double)],
                      sessions: [CachedSleepSession] = [],
                      now: Date = Date(), calendar: Calendar = .current,
                      resolvedDaily: [String: [String: Double]]? = nil) -> NoopTrendsRecord {
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
            let samples = rows.compactMap { key, value -> DatedChartSeries.Sample? in
                guard value.isFinite, value > 0, let date = HistoryDateWindow.date(dayKey: key, timeZone: cal.timeZone) else { return nil }
                return .init(date: date, value: value)
            }
            return DatedChartSeries(samples: samples).weeklyAverages(startingOn: starts, through: now, calendar: cal)
        }

        var record = NoopTrendsRecord()
        record.weekStarts = starts
        record.restingPulse = weekly(resolvedDaily?["rhr"].map { $0.map { ($0.key, $0.value) } }
            ?? days.compactMap { d in d.restingHr.map { (d.day, Double($0)) } })
        record.variability = weekly(resolvedDaily?["hrv"].map { $0.map { ($0.key, $0.value) } }
            ?? days.compactMap { d in d.avgHrv.map { (d.day, $0) } })
        record.sleep = weekly(resolvedDaily?["sleep_total_min"].map { $0.map { ($0.key, $0.value / 60) } }
            ?? days.compactMap { d in d.totalSleepMin.map { (d.day, $0 / 60) } })
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
        record.throughDay = today
        record.loaded = true
        return record
    }
}

@MainActor
final class NoopTrendsStore: ObservableObject {
    @Published private(set) var record = NoopTrendsRecord()
    private var loadingDeviceId: String?
    private var requestId = UUID()

    func load(from repo: Repository) async {
        guard repo.loaded else { return }
        let device = repo.deviceId
        if loadingDeviceId != device { record = NoopTrendsRecord() }
        loadingDeviceId = device
        let request = UUID()
        requestId = request
        let sequence = repo.refreshSeq
        let resolvedDaily = await NoopTrendDailyHistory.load(from: repo)
        let capacity = (resolvedDaily["cap"] ?? [:]).map { (day: $0.key, value: $0.value) }
        let sessions = await repo.allSleepSessions()
        guard !Task.isCancelled, requestId == request, repo.deviceId == device, repo.refreshSeq == sequence else { return }
        record = NoopTrendsRecord.build(days: repo.days, capacityDays: capacity,
                                        sessions: sessions.isEmpty ? repo.sleeps : sessions,
                                        resolvedDaily: resolvedDaily)
    }
}
/// One source policy for the four metrics shared by Trends and the daily explorer.
@MainActor
enum NoopTrendDailyHistory {
    static func load(from repo: Repository) async -> [String: [String: Double]] {
        func series(_ key: String, source: String = Repository.whoopSource) async -> [String: Double] {
            let result = await repo.resolvedSeries(key: key, source: source, fullHistory: true)
            return Dictionary(result.values.map { ($0.day, $0.value) }, uniquingKeysWith: { _, last in last })
        }
        var result: [String: [String: Double]] = [:]
        for key in ["rhr", "hrv", "sleep_total_min"] { result[key] = await series(key) }
        result["cap"] = await series("vo2max_est")
        if result["cap"]?.isEmpty != false {
            result["cap"] = await series("vo2max", source: Repository.appleHealthSource)
        }
        return result
    }
}
#endif
