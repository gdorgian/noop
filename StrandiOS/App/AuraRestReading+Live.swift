#if os(iOS)
import Foundation
import SwiftUI
import StrandAnalytics
import StrandDesign
import WhoopStore

extension AuraRestReading {

    /// Adapts NOOP's canonical sleep model into Aura's presentation model. Main-sleep selection,
    /// fragment bridging and stage decoding all stay owned by `SleepModel`; this layer only formats
    /// those resolved values for the design.
    static func live(
        days: [DailyMetric],
        sessions: [CachedSleepSession],
        habitualMidsleepSec: Int?
    ) -> AuraRestReading {
        let trailingDays = Array(days.suffix(30))
        let baselineMinutes = trailingDays.compactMap(\.totalSleepMin).filter { $0 > 0 }
        let deepMinutes = trailingDays.compactMap(\.deepMin).filter { $0 > 0 }

        let navDays = SleepModel.navDays(navSessions: sessions)
        let decodedNewestFirst = navDays.prefix(7).compactMap {
            SleepModel.mergeDay($0, habitualMidsleepSec: habitualMidsleepSec, motionByStart: [:])
        }
        let decoded = Array(decodedNewestFirst.reversed())

        let fallbackAverage = mean(decoded.map { $0.stages.asleep })
        let personalAverageMinutes = mean(baselineMinutes) ?? fallbackAverage
        let personalAverageHours = (personalAverageMinutes ?? 0) / 60

        let nights = decoded.map { night in
            mappedNight(
                night,
                personalAverageMinutes: personalAverageMinutes
            )
        }

        let naps = SleepModel.napSleepMinutesByDay(
            navDays: navDays,
            habitualMidsleepSec: habitualMidsleepSec
        )
        let ledger = SleepModel.debtLedger(days: days, napSleepMinByDay: naps)

        return AuraRestReading(
            nights: nights,
            personalAverage: personalAverageHours,
            averageNote: averageNote(
                baselineMinutes: personalAverageMinutes,
                baselineCount: baselineMinutes.count,
                nights: nights
            ),
            averageSleepValue: decimalHours(personalAverageMinutes),
            averageDeepValue: decimalHours(mean(deepMinutes)),
            debtHeadline: debtHeadline(ledger),
            debtExplanation: debtExplanation(ledger),
            debtIsDebt: ledger.isDebt,
            debtNights: ledger.nights.map(debtNight)
        )
    }

    private static func mappedNight(
        _ night: Night,
        personalAverageMinutes: Double?
    ) -> AuraRestReading.NightReading {
        let minutes = night.stages.asleep
        return AuraRestReading.NightReading(
            id: night.session.effectiveStartTs,
            day: dayFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(night.session.endTs))),
            dateLabel: shortDateFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(night.session.endTs))),
            hours: minutes / 60,
            note: note(for: night, minutes: minutes, personalAverageMinutes: personalAverageMinutes),
            window: "\(night.onsetText) – \(night.wakeText)",
            hypnogram: hypnogram(for: night),
            hypnogramAxis: axisLabels(for: night),
            stages: stageRows(night.stages)
        )
    }

    private static func stageRows(_ stages: Stages) -> [AuraRestReading.Stage] {
        let values: [(String, String, Double, Int)] = [
            ("deep", String(localized: "Deep"), stages.deep, 3),
            ("rem", String(localized: "REM"), stages.rem, 2),
            ("light", String(localized: "Light"), stages.light, 1),
            ("awake", String(localized: "Awake"), stages.awake, 0),
        ]
        let widest = max(values.map(\.2).max() ?? 0, 1)
        return values.map { id, name, minutes, colorIndex in
            AuraRestReading.Stage(
                id: id,
                name: name,
                duration: durationText(minutes),
                fraction: minutes / widest,
                tint: AuraHypnogram.stageColors[colorIndex]
            )
        }
    }

    /// Converts the real persisted stage intervals into the design's fixed-width strip. Imported nights
    /// that only contain aggregate totals deliberately return an empty strip instead of inventing stage
    /// order; their real totals still appear in the four rows below it.
    private static func hypnogram(for night: Night, sampleCount: Int = 34) -> [Int] {
        guard let intervals = night.realSegments, !intervals.isEmpty, sampleCount > 0 else { return [] }
        let span = TimeInterval(max(night.session.endTs - night.session.effectiveStartTs, 1))
        return (0..<sampleCount).map { index in
            let lo = span * Double(index) / Double(sampleCount)
            let hi = span * Double(index + 1) / Double(sampleCount)
            var overlap = [Double](repeating: 0, count: 4)
            for interval in intervals {
                let seconds = max(0, min(hi, interval.end) - max(lo, interval.start))
                overlap[stageIndex(interval.stage)] += seconds
            }
            return overlap.enumerated().max(by: { $0.element < $1.element })?.offset ?? 0
        }
    }

    private static func stageIndex(_ stage: SleepStage) -> Int {
        switch stage {
        case .awake: return 0
        case .light: return 1
        case .rem: return 2
        case .deep: return 3
        }
    }

    private static func axisLabels(for night: Night) -> [String] {
        let start = TimeInterval(night.session.effectiveStartTs)
        let span = TimeInterval(max(night.session.endTs - night.session.effectiveStartTs, 1))
        return [0.0, 1.0 / 3.0, 2.0 / 3.0, 1.0].map { fraction in
            axisFormatter.string(from: Date(timeIntervalSince1970: start + span * fraction))
        }
    }

    private static func note(for night: Night, minutes: Double, personalAverageMinutes: Double?) -> String {
        if night.sourceBlocks.contains(where: { $0.stagingSparse == true }) {
            return String(localized: "Sleep staging may be incomplete because strap coverage was sparse.")
        }
        guard let personalAverageMinutes else {
            return String(localized: "This is your first recorded night.")
        }
        let delta = Int((minutes - personalAverageMinutes).rounded())
        if abs(delta) < 15 { return String(localized: "This night was close to your normal.") }
        if delta > 0 { return String(localized: "You slept \(durationText(Double(delta))) above your normal.") }
        return String(localized: "You slept \(durationText(Double(-delta))) below your normal.")
    }

    private static func averageNote(
        baselineMinutes: Double?,
        baselineCount: Int,
        nights: [AuraRestReading.NightReading]
    ) -> String {
        guard let baselineMinutes, baselineCount > 0 else {
            return String(localized: "Wear your strap overnight to start building your personal sleep baseline.")
        }
        let above = nights.filter { $0.hours * 60 > baselineMinutes }.count
        return String(localized: "The dashed line is your \(baselineCount)-night average, \(durationText(baselineMinutes)) — \(above) of \(nights.count) recent nights were above it.")
    }

    private static func mean(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private static func decimalHours(_ minutes: Double?) -> String {
        minutes.map { String(format: "%.1f", $0 / 60) } ?? "—"
    }

    private static func durationText(_ minutes: Double) -> String {
        let rounded = max(0, Int(minutes.rounded()))
        if rounded < 60 { return String(localized: "\(rounded)m") }
        return String(localized: "\(rounded / 60)h \(rounded % 60)m")
    }

    private static func debtHeadline(_ ledger: SleepDebtLedger) -> String {
        guard ledger.nightCount > 0 else { return String(localized: "No history") }
        if ledger.magnitudeMin < SleepDebt.onTargetBandMin { return String(localized: "On target") }
        let amount = durationText(ledger.magnitudeMin)
        return ledger.isDebt ? String(localized: "\(amount) debt") : String(localized: "\(amount) ahead")
    }

    private static func debtExplanation(_ ledger: SleepDebtLedger) -> String {
        guard ledger.nightCount > 0 else {
            return String(localized: "Sleep debt appears after NOOP has enough recorded nights to compare with your sleep need.")
        }
        let need = durationText(ledger.needMin)
        return String(localized: "Running balance across \(ledger.nightCount) recorded nights against a \(need) nightly need. Short nights add debt; longer nights pay it back.")
    }

    private static func debtNight(_ night: SleepDebtNight) -> AuraRestReading.DebtNight {
        let added = night.deltaMin < 0
        let magnitude = durationText(abs(night.deltaMin))
        let change = added
            ? String(localized: "+\(magnitude) debt")
            : String(localized: "−\(magnitude) debt")
        return AuraRestReading.DebtNight(
            id: night.day,
            date: shortDayKey(night.day),
            slept: String(localized: "\(durationText(night.sleptMin)) slept"),
            change: change,
            addedDebt: added
        )
    }

    private static func shortDayKey(_ day: String) -> String {
        guard let date = dayParser.date(from: day) else { return day }
        return shortDateFormatter.string(from: date)
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = AppLanguage.activeLocale
        formatter.setLocalizedDateFormatFromTemplate("EEEEE")
        return formatter
    }()

    private static let dayParser: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = AppLanguage.activeLocale
        formatter.setLocalizedDateFormatFromTemplate("dM")
        return formatter
    }()

    private static let axisFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = AppLanguage.activeLocale
        formatter.setLocalizedDateFormatFromTemplate("j")
        return formatter
    }()
}
#endif
