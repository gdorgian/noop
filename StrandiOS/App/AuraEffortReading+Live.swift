#if os(iOS)
import Foundation
import SwiftUI
import StrandDesign
import WhoopStore

extension AuraEffortReading {

    /// Adapts NOOP's stored 0...100 daily Effort and reconciled workouts into Aura's presentation.
    /// Recovery chooses the already-shipped optimal band; no load, workout or target is recomputed here.
    @MainActor static func live(
        day: DailyMetric?,
        targetRecovery: Double?,
        history: [DailyMetric],
        workouts: [WorkoutRow],
        scale: EffortScale,
        now: Date = Date()
    ) -> AuraEffortReading {
        let anchorKey = day?.day ?? Repository.logicalDayKey(now)
        let storedEffort = day?.strain
        let displayEffort = storedEffort.map { UnitFormatter.effortValue($0, scale: scale) }
        let target21 = CoupledView.optimalStrainRange(recovery: targetRecovery)
        let target = target21.map { displayRange($0, scale: scale) }
        let week = weekReadings(endingOn: anchorKey, history: history, scale: scale)

        let todayWorkouts = workouts
            .filter {
                Repository.logicalDayKey(Date(timeIntervalSince1970: TimeInterval($0.startTs))) == anchorKey
            }
            .sorted { $0.startTs > $1.startTs }

        return AuraEffortReading(
            greeting: fullWeekdayLabel(anchorKey),
            effort: storedEffort.map { UnitFormatter.effortDisplay($0, scale: scale) } ?? "—",
            targetCaption: target.map { String(localized: "target \(format($0.lowerBound))–\(format($0.upperBound))") }
                ?? String(localized: "target pending"),
            fraction: min(max((storedEffort ?? 0) / 100, 0), 1),
            stops: [
                (label: String(localized: "Minimal"), position: 8),
                (label: String(localized: "Moderate"), position: 52),
                (label: String(localized: "All out"), position: 92),
            ],
            note: targetNote(effort: displayEffort, target: target),
            activities: todayWorkouts.enumerated().map { index, row in
                mappedActivity(row, index: index, scale: scale)
            },
            weekLoad: week.values,
            weekDays: week.labels,
            weekVerdict: weekVerdict(rows: week.rows, scale: scale),
            weekCeiling: scale == .whoop ? 21 : 100,
            headline: effortHeadline(effort21: storedEffort.map { UnitFormatter.effortValue($0, scale: .whoop) },
                                     target21: target21)
        )
    }

    private static func mappedActivity(
        _ row: WorkoutRow,
        index: Int,
        scale: EffortScale
    ) -> AuraEffortReading.Activity {
        let duration = row.durationS ?? Double(max(row.endTs - row.startTs, 0))
        var detail: [String] = []
        if duration > 0 { detail.append(durationText(duration)) }
        if let avgHr = row.avgHr { detail.append(String(localized: "\(avgHr) bpm average")) }
        if detail.isEmpty { detail.append(String(localized: "Recorded activity")) }

        let tints: [Color] = [AuraPalette.accent, AuraPalette.effort, AuraPalette.rest]
        return AuraEffortReading.Activity(
            id: "\(row.startTs):\(row.sport)",
            name: WorkoutSource.displaySport(row.sport),
            detail: detail.joined(separator: " · "),
            load: row.strain.map { UnitFormatter.effortDisplay($0, scale: scale) } ?? "—",
            tint: tints[index % tints.count]
        )
    }

    private static func targetNote(effort: Double?, target: ClosedRange<Double>?) -> String {
        guard let target else {
            return String(localized: "Charge is still calibrating. Your recovery-matched Effort range will appear when it is ready.")
        }
        guard let effort else {
            return String(localized: "Effort will appear as today’s heart-rate data accumulates. Your current target range is \(format(target.lowerBound))–\(format(target.upperBound)).")
        }
        if effort < target.lowerBound {
            return String(localized: "\(format(target.lowerBound - effort)) more Effort reaches today’s recovery-matched range.")
        }
        if effort <= target.upperBound {
            return String(localized: "You’re inside today’s recovery-matched range.")
        }
        return String(localized: "You’re above today’s recovery-matched range. That is context, not a penalty.")
    }

    private static func effortHeadline(
        effort21: Double?,
        target21: ClosedRange<Int>?
    ) -> String {
        guard let effort21 else { return String(localized: "No Effort scored yet") }
        guard let target21 else { return String(localized: "Effort so far today") }
        if effort21 < Double(target21.lowerBound) { return String(localized: "You have room to move") }
        if effort21 <= Double(target21.upperBound) { return String(localized: "You’re in today’s range") }
        return String(localized: "You’ve passed today’s range")
    }

    private static func displayRange(
        _ range: ClosedRange<Int>,
        scale: EffortScale
    ) -> ClosedRange<Double> {
        if scale == .whoop {
            return Double(range.lowerBound)...Double(range.upperBound)
        }
        let factor = 100.0 / 21.0
        return (Double(range.lowerBound) * factor).rounded()...(Double(range.upperBound) * factor).rounded()
    }

    private static func weekReadings(
        endingOn anchorKey: String,
        history: [DailyMetric],
        scale: EffortScale
    ) -> (values: [Double], labels: [String], rows: [DailyMetric]) {
        guard let anchor = dayParser.date(from: anchorKey) else {
            let rows = Array(history.filter { $0.day <= anchorKey }.suffix(7))
            return (
                rows.map { $0.strain.map { UnitFormatter.effortValue($0, scale: scale) } ?? 0 },
                rows.map { dayLabel($0.day) },
                rows
            )
        }

        let byDay = Dictionary(history.map { ($0.day, $0) }, uniquingKeysWith: { _, last in last })
        let keys = (-6...0).compactMap { offset -> String? in
            Calendar.current.date(byAdding: .day, value: offset, to: anchor).map {
                dayParser.string(from: $0)
            }
        }
        let rows = keys.compactMap { byDay[$0] }
        return (
            keys.map { key in
                byDay[key]?.strain.map { UnitFormatter.effortValue($0, scale: scale) } ?? 0
            },
            keys.map(dayLabel),
            rows
        )
    }

    private static func weekVerdict(rows: [DailyMetric], scale: EffortScale) -> String {
        let recorded = rows.compactMap { row -> (effort: Double, target: ClosedRange<Double>?)? in
            guard let strain = row.strain else { return nil }
            let target = CoupledView.optimalStrainRange(recovery: row.recovery).map {
                displayRange($0, scale: scale)
            }
            return (UnitFormatter.effortValue(strain, scale: scale), target)
        }
        guard !recorded.isEmpty else { return String(localized: "No recorded Effort") }

        let comparable = recorded.compactMap { row -> (Double, ClosedRange<Double>)? in
            guard let target = row.target else { return nil }
            return (row.effort, target)
        }
        guard !comparable.isEmpty else {
            return String(localized: "\(recorded.count) recorded days")
        }

        let effortAverage = comparable.map(\.0).reduce(0, +) / Double(comparable.count)
        let lowerAverage = comparable.map { $0.1.lowerBound }.reduce(0, +) / Double(comparable.count)
        let upperAverage = comparable.map { $0.1.upperBound }.reduce(0, +) / Double(comparable.count)
        if effortAverage < lowerAverage { return String(localized: "Below your range") }
        if effortAverage > upperAverage { return String(localized: "Above your range") }
        return String(localized: "Balanced")
    }

    private static func durationText(_ seconds: Double) -> String {
        let minutes = max(1, Int((seconds / 60).rounded()))
        if minutes < 60 { return String(localized: "\(minutes) min") }
        let remainder = minutes % 60
        return remainder == 0
            ? String(localized: "\(minutes / 60) hr")
            : String(localized: "\(minutes / 60) hr \(remainder) min")
    }

    private static func format(_ value: Double) -> String {
        let rounded = value.rounded()
        return abs(value - rounded) < 0.05
            ? String(Int(rounded))
            : String(format: "%.1f", value)
    }

    private static func dayLabel(_ day: String) -> String {
        guard let date = dayParser.date(from: day) else { return "" }
        return weekdayFormatter.string(from: date)
    }

    private static func fullWeekdayLabel(_ day: String) -> String {
        guard let date = dayParser.date(from: day) else { return String(localized: "Today") }
        return fullWeekdayFormatter.string(from: date)
    }

    private static let dayParser: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = AppLanguage.activeLocale
        formatter.setLocalizedDateFormatFromTemplate("EEEEE")
        return formatter
    }()

    private static let fullWeekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = AppLanguage.activeLocale
        formatter.setLocalizedDateFormatFromTemplate("EEEE")
        return formatter
    }()
}
#endif
