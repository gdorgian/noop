#if os(iOS)
import Foundation
import StrandAnalytics
import WhoopStore

extension AuraTrendsReading {

    /// Builds Aura's trend snapshots from NOOP's merged daily rows and the same nap-aware sleep-debt
    /// ledger used by the canonical Sleep screen. Missing dates stay missing; no chart point is zero-filled.
    @MainActor static func live(
        days: [DailyMetric],
        sessions: [CachedSleepSession],
        habitualMidsleepSec: Int?,
        now: Date = Date()
    ) -> AuraTrendsReading {
        let todayKey = Repository.localDayKey(now)
        let chargeRows = days
            .filter { $0.day <= todayKey && $0.recovery != nil }
            .sorted { $0.day < $1.day }

        let normal = personalNormal(Array(chargeRows.suffix(30)).compactMap(\.recovery))
        let fortnight = series(days: 14, rows: chargeRows, todayKey: todayKey, normal: normal)
        let month = series(days: 30, rows: chargeRows, todayKey: todayKey, normal: normal)
        let quarter = series(days: 90, rows: chargeRows, todayKey: todayKey, normal: normal)

        let navDays = SleepModel.navDays(navSessions: sessions)
        let naps = SleepModel.napSleepMinutesByDay(
            navDays: navDays,
            habitualMidsleepSec: habitualMidsleepSec
        )
        let ledger = SleepModel.debtLedger(days: days, napSleepMinByDay: naps)

        return AuraTrendsReading(
            fortnight: fortnight,
            month: month,
            quarter: quarter,
            debt: ledger.nights.map { max(-$0.deltaMin / 60, 0) },
            debtVerdict: debtVerdict(ledger),
            headline: trendHeadline(fortnight.values)
        )
    }

    private static func series(
        days count: Int,
        rows: [DailyMetric],
        todayKey: String,
        normal: ClosedRange<Double>?
    ) -> AuraTrendsReading.Series {
        let cutoff = dayKey(offset: -(count - 1), from: todayKey) ?? todayKey
        let points = rows.compactMap { row -> (day: String, value: Double)? in
            guard row.day >= cutoff, row.day <= todayKey, let value = row.recovery else { return nil }
            return (row.day, value)
        }
        let labels = points.map { pointLabel($0.day, todayKey: todayKey) }

        return AuraTrendsReading.Series(
            values: points.map(\.value),
            labels: labels,
            axis: axisLabels(points.map(\.day), todayKey: todayKey),
            read: trendRead(points.map(\.value), windowDays: count),
            normalRange: normal,
            chargeNote: normal.map {
                String(localized: "Your normal \(Int($0.lowerBound.rounded()))–\(Int($0.upperBound.rounded()))")
            } ?? readingCount(points.count)
        )
    }

    /// The middle 50% of the wearer's trailing 30 valid Charge readings. Four readings are the minimum
    /// before a range is called "normal"; below that, the card reports only the honest reading count.
    private static func personalNormal(_ values: [Double]) -> ClosedRange<Double>? {
        guard values.count >= 4 else { return nil }
        let sorted = values.sorted()
        return quantile(sorted, 0.25)...quantile(sorted, 0.75)
    }

    private static func quantile(_ sorted: [Double], _ q: Double) -> Double {
        guard sorted.count > 1 else { return sorted.first ?? 0 }
        let position = min(max(q, 0), 1) * Double(sorted.count - 1)
        let lower = Int(position.rounded(.down))
        let upper = min(lower + 1, sorted.count - 1)
        let fraction = position - Double(lower)
        return sorted[lower] + fraction * (sorted[upper] - sorted[lower])
    }

    private static func trendRead(_ values: [Double], windowDays: Int) -> String {
        guard values.count >= 4 else {
            return values.isEmpty
                ? String(localized: "No Charge readings fall inside this window yet.")
                : String(localized: "Only \(values.count) Charge readings fall inside this window. Keep wearing the strap to reveal a reliable direction.")
        }
        let split = values.count / 2
        let early = mean(Array(values.prefix(split)))
        let recent = mean(Array(values.suffix(values.count - split)))
        let delta = recent - early
        let direction: String
        if delta >= 5 {
            direction = String(localized: "Your recent Charge average is \(Int(abs(delta).rounded())) points higher than the earlier half.")
        } else if delta <= -5 {
            direction = String(localized: "Your recent Charge average is \(Int(abs(delta).rounded())) points lower than the earlier half.")
        } else {
            direction = String(localized: "Your recent Charge average is within \(Int(abs(delta).rounded())) points of the earlier half.")
        }
        return String(localized: "Across \(values.count) recorded days in this \(windowDays)-day window, \(direction)")
    }

    private static func trendHeadline(_ values: [Double]) -> String {
        guard values.count >= 4 else { return String(localized: "Your Charge history") }
        let split = values.count / 2
        let delta = mean(Array(values.suffix(values.count - split))) - mean(Array(values.prefix(split)))
        if delta >= 5 { return String(localized: "Your Charge is trending up") }
        if delta <= -5 { return String(localized: "Your Charge is trending down") }
        return String(localized: "Your Charge is holding steady")
    }

    private static func debtVerdict(_ ledger: SleepDebtLedger) -> String {
        guard ledger.nightCount > 0 else { return String(localized: "No sleep history") }
        if ledger.magnitudeMin < SleepDebt.onTargetBandMin { return String(localized: "On target") }
        let duration = durationText(ledger.magnitudeMin)
        return ledger.isDebt
            ? String(localized: "≈\(duration) debt")
            : String(localized: "≈\(duration) ahead")
    }

    private static func durationText(_ minutes: Double) -> String {
        let value = max(0, Int(minutes.rounded()))
        if value < 60 { return String(localized: "\(value)m") }
        return value % 60 == 0
            ? String(localized: "\(value / 60)h")
            : String(localized: "\(value / 60)h \(value % 60)m")
    }

    private static func mean(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    private static func readingCount(_ count: Int) -> String {
        count == 1
            ? String(localized: "1 recorded day")
            : String(localized: "\(count) recorded days")
    }

    private static func axisLabels(_ days: [String], todayKey: String) -> [String] {
        guard !days.isEmpty else { return [] }
        let last = days.count - 1
        let candidates = [0, last / 3, (last * 2) / 3, last]
        var seen = Set<Int>()
        return candidates.compactMap { index in
            guard seen.insert(index).inserted else { return nil }
            return pointLabel(days[index], todayKey: todayKey)
        }
    }

    private static func pointLabel(_ day: String, todayKey: String) -> String {
        if day == todayKey { return String(localized: "Today") }
        guard let date = dayParser.date(from: day) else { return day }
        return pointFormatter.string(from: date)
    }

    private static func dayKey(offset: Int, from day: String) -> String? {
        guard let date = dayParser.date(from: day),
              let shifted = Calendar.current.date(byAdding: .day, value: offset, to: date) else { return nil }
        return dayParser.string(from: shifted)
    }

    private static let dayParser: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let pointFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = AppLanguage.activeLocale
        formatter.setLocalizedDateFormatFromTemplate("dMMM")
        return formatter
    }()
}
#endif
