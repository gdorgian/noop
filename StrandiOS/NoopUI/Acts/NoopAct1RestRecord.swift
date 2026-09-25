#if os(iOS)
import Foundation
import StrandAnalytics
import StrandDesign
import WhoopStore

/// The Rest home screen's real-data model, for the production shell.
///
/// Built from the SAME pure pipeline the classic Sleep tab uses (`SleepModel.navDays`,
/// `SleepModel.decodedNight`, `SleepModel.debtNeedMin`), so the night, its stages and the need the
/// ring closes at are the numbers the rest of the app already reports. Nothing here is drawn from the
/// design's example person, and nothing is estimated to fill a gap:
///
/// - A day with no recorded night stays an empty slot in the seven-night strip.
/// - A night with no per-epoch timeline (an imported night carries totals only) gets its stage totals
///   and NO ring or hypnogram stage sequence. `Night.intervals` would synthesize "a plausible
///   architecture" for it; drawing that would present an invented order of stages as a measurement.
struct NoopRestRecord: Equatable {
    enum Phase: Equatable { case loading, empty, ready }

    /// Debt ranges the screen offers, in nights.
    static let debtRanges: [(label: String, nights: Int)] = [("14 nights", 14), ("30 nights", 30), ("3 months", 90)]

    struct StageMinutes: Equatable {
        let deep: Double
        let rem: Double
        let light: Double
        let awake: Double
        var asleep: Double { deep + rem + light }
    }

    struct Night: Equatable {
        let dayKey: String
        let weekdayLetter: String
        /// "Sat 12 Sep" — the header and row titles when this is not the latest night.
        let longDate: String
        /// "12 Sep".
        let shortDate: String
        let endDate: Date
        let asleepMin: Double
        /// "23:14 – 06:41", in the wearer's clock setting.
        let window: String
        let stages: StageMinutes
        /// Stage per equal slice of the night (0 awake · 1 light · 2 REM · 3 deep), only when a real
        /// timeline exists.
        let slices: [Int]?
        /// Four clock labels across the night for the hypnogram, only when a real timeline exists.
        let axis: [String]?
    }

    let phase: Phase
    /// Seven calendar days ending today, oldest → newest. Nil where no night was recorded.
    let slots: [Night?]
    /// The newest recorded night, however old. The hero shows it (with its date) when the last seven
    /// days hold none — an older night on record is not "no night recorded".
    let latest: Night?
    /// The normative per-wearer need `SleepDebt` measures against (`SleepModel.debtNeedMin`). One need
    /// for the ring, the seven-night dashes and the debt surfaces, so the screen never shows two.
    let needMin: Double
    /// Nights behind the need estimate — the count the confidence chip reports.
    let needNights: Int
    /// The running debt in minutes (positive = behind) per day with a usable night, oldest → newest,
    /// from `SleepDebt.debtSeries` — the same recurrence every debt surface reads.
    var debt: [(day: String, minutes: Double)] = []
    /// Each usable night's sleep against the need, in minutes (negative = short).
    var nightDeltas: [(day: String, minutes: Double)] = []
    /// Time from getting into bed to first sleep. The current store has a detected sleep-session
    /// onset and sleep stages, but no verified in-bed start, so this stays nil. An awake segment at
    /// the start of a detected timeline is not evidence of when the wearer lay down.
    var latencyMin: Double?

    /// The design's full-confidence window for the need ("21 of 90 nights").
    static let needSolidNights = 90
    /// Slices in the ring and the hypnogram — the prototype's count, so bars keep the drawn width.
    static let sliceCount = 34

    static let loading = NoopRestRecord(phase: .loading, slots: Array(repeating: nil, count: 7),
                                        latest: nil, needMin: 0, needNights: 0)

    static func == (a: Self, b: Self) -> Bool {
        a.phase == b.phase && a.slots == b.slots && a.latest == b.latest && a.needMin == b.needMin
            && a.needNights == b.needNights && a.debt.map(\.minutes) == b.debt.map(\.minutes)
    }

    enum Confidence: Equatable { case calibrating, building, solid }

    /// Calibrating while the engine is still answering with the population default (fewer than
    /// `minNeedNights` nights); building until the design's 90-night window is full; solid after.
    var confidence: Confidence {
        if needNights < AnalyticsEngine.Rest.minNeedNights { return .calibrating }
        return needNights < Self.needSolidNights ? .building : .solid
    }

    var newestIndex: Int? { slots.lastIndex { $0 != nil } }

    // MARK: - Build

    static func build(days: [DailyMetric],
                      sessions: [CachedSleepSession],
                      habitualMidsleepSec: Int?,
                      importedDebtMin: [String: Double] = [:],
                      now: Date = Date(),
                      calendar: Calendar = .current) -> NoopRestRecord {
        let dayGroups = SleepModel.navDays(navSessions: sessions)
        var byDay: [String: Night] = [:]
        var latest: Night?
        let today = calendar.startOfDay(for: now)
        let windowStart = calendar.date(byAdding: .day, value: -6, to: today) ?? today
        for offset in dayGroups.indices {
            guard let night = SleepModel.decodedNight(at: offset, navDays: dayGroups,
                                                      habitualMidsleepSec: habitualMidsleepSec,
                                                      motionByStart: [:]) else { continue }
            let end = Date(timeIntervalSince1970: TimeInterval(night.session.endTs))
            let endDay = calendar.startOfDay(for: end)
            // navDays is newest first. After the seven-day strip, only the newest older night
            // matters; no timeline can establish sleep-onset latency without an in-bed start.
            if endDay < windowStart && latest != nil { break }
            let stages = StageMinutes(deep: night.stages.deep, rem: night.stages.rem,
                                      light: night.stages.light, awake: night.stages.awake)
            guard stages.asleep > 0 else { continue }
            let key = Repository.localDayKey(end)
            let real = (night.realSegments?.count ?? 0) >= 2 ? night.realSegments : nil
            let built = Night(
                dayKey: key,
                weekdayLetter: weekdayLetter(end, calendar: calendar),
                longDate: longDateFormatter.string(from: end),
                shortDate: shortDateFormatter.string(from: end),
                endDate: end,
                asleepMin: stages.asleep,
                window: "\(night.onsetText) \u{2013} \(night.wakeText)",
                stages: stages,
                slices: real.map { slices(of: $0) },
                axis: real.map { _ in axis(onset: night.onsetDate, wake: end, calendar: calendar) }
            )
            if latest == nil { latest = built }
            if endDay < windowStart && latest != built { continue }
            if endDay >= windowStart { byDay[key] = built }
        }

        let slots: [Night?] = (0..<7).map { index in
            guard let day = calendar.date(byAdding: .day, value: index - 6, to: today) else { return nil }
            return byDay[Repository.localDayKey(day)]
        }
        let needNights = days.filter { ($0.totalSleepMin ?? 0) > 0 }.count
        let needMin = SleepModel.debtNeedMin(days: days)
        var record = NoopRestRecord(
            phase: latest == nil ? .empty : .ready,
            slots: slots,
            latest: latest,
            needMin: needMin,
            needNights: needNights
        )
        let series = days.map { (day: $0.day, totalSleepMin: SleepDebt.creditedSleepMin(mainSleepMin: $0.totalSleepMin)) }
        record.debt = SleepDebt.debtSeries(series: series, needHours: needMin / 60, importedDebtMin: importedDebtMin)
            .suffix(90).map { (day: $0.day, minutes: max(0, $0.value)) }
        record.nightDeltas = series.compactMap { row in row.totalSleepMin.map { (day: row.day, minutes: $0 - needMin) } }
            .suffix(90).map { $0 }
        return record
    }

    /// The dominant stage in each of `sliceCount` equal time slices of the recorded timeline.
    static func slices(of intervals: [SleepInterval]) -> [Int] {
        guard let first = intervals.map(\.start).min(),
              let last = intervals.map(\.end).max(), last > first else { return [] }
        let width = (last - first) / Double(sliceCount)
        return (0..<sliceCount).map { index in
            let lo = first + Double(index) * width, hi = lo + width
            var seconds: [Int: Double] = [:]
            for interval in intervals {
                let overlap = min(hi, interval.end) - max(lo, interval.start)
                if overlap > 0 { seconds[stageIndex(interval.stage), default: 0] += overlap }
            }
            return seconds.max { $0.value < $1.value }?.key ?? 0
        }
    }

    static func stageIndex(_ stage: SleepStage) -> Int {
        switch stage {
        case .awake: 0
        case .light: 1
        case .rem: 2
        case .deep: 3
        }
    }

    /// Onset, two half-hour-rounded points between, and wake — the prototype's four labels.
    static func axis(onset: Date, wake: Date, calendar: Calendar) -> [String] {
        let span = wake.timeIntervalSince(onset)
        func rounded(_ date: Date) -> Date {
            let half: TimeInterval = 30 * 60
            return Date(timeIntervalSince1970: (date.timeIntervalSince1970 / half).rounded() * half)
        }
        let fmt = AppClock.hourMinuteFormatter()
        return [onset, rounded(onset.addingTimeInterval(span / 3)),
                rounded(onset.addingTimeInterval(span * 2 / 3)), wake].map { fmt.string(from: $0) }
    }

    private static func weekdayLetter(_ date: Date, calendar: Calendar) -> String {
        let symbols = calendar.veryShortWeekdaySymbols
        return symbols[calendar.component(.weekday, from: date) - 1]
    }

    private static let longDateFormatter: DateFormatter = {
        let f = DateFormatter(); f.setLocalizedDateFormatFromTemplate("EEE d MMM"); return f
    }()
    private static let shortDateFormatter: DateFormatter = {
        let f = DateFormatter(); f.setLocalizedDateFormatFromTemplate("d MMM"); return f
    }()

    // MARK: - Formatting, computed once and shared by every place a number is printed

    /// "7h 12m", "6h 06m", "48m".
    static func duration(_ minutes: Double) -> String {
        let total = max(0, Int(minutes.rounded()))
        if total < 60 { return "\(total)m" }
        return "\(total / 60)h " + String(format: "%02dm", total % 60)
    }

    /// "7m over", "1h 35m short", "5m short — even". Within five minutes either way reads as even.
    static func delta(asleepMin: Double, needMin: Double) -> (text: String, closes: Bool) {
        let diff = (asleepMin - needMin).rounded()
        if diff >= 0 { return ("\(duration(diff)) over", true) }
        let short = "\(duration(-diff)) short"
        return -diff <= 5 ? ("\(short) \u{2014} even", true) : (short, false)
    }
}

/// Loads `NoopRestRecord` off the repository, once per data change.
@MainActor
final class NoopRestStore: ObservableObject {
    @Published private(set) var record: NoopRestRecord = .loading

    func load(from repo: Repository) async {
        guard repo.loaded else { record = .loading; return }
        let sessions = await repo.allSleepSessions()
        let habitual = await repo.habitualMidsleepSec()
        record = NoopRestRecord.build(days: repo.days,
                                      sessions: sessions.isEmpty ? repo.sleeps : sessions,
                                      habitualMidsleepSec: habitual,
                                      importedDebtMin: repo.importedSleep.compactMapValues(\.debtMin))
    }
}
#endif
