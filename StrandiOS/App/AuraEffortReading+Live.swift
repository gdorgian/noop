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
        targetDay: DailyMetric?,
        history: [DailyMetric],
        workouts: [WorkoutRow],
        scale: EffortScale,
        now: Date = Date()
    ) -> AuraEffortReading {
        let anchorKey = day?.day ?? Repository.logicalDayKey(now)
        let storedEffort = day?.strain
        let displayEffort = storedEffort.map { UnitFormatter.effortValue($0, scale: scale) }
        let target21 = CoupledView.optimalStrainRange(recovery: targetDay?.recovery)
        let target = target21.map { displayRange($0, scale: scale) }
        let targetIsCurrent = targetDay?.day == anchorKey
        let week = weekReadings(endingOn: anchorKey, history: history, scale: scale)
        let weekHighlighted = week.rows.lastIndex(where: { $0.day == anchorKey }) ?? -1

        let todayWorkouts = workouts
            .filter {
                Repository.logicalDayKey(Date(timeIntervalSince1970: TimeInterval($0.startTs))) == anchorKey
            }
            .sorted { $0.startTs > $1.startTs }

        return AuraEffortReading(
            greeting: fullWeekdayLabel(anchorKey),
            effort: storedEffort.map { UnitFormatter.effortDisplay($0, scale: scale) } ?? "—",
            targetCaption: target.map {
                targetIsCurrent
                    ? String(localized: "target \(format($0.lowerBound))–\(format($0.upperBound))")
                    : String(localized: "latest target \(format($0.lowerBound))–\(format($0.upperBound))")
            }
                ?? String(localized: "target pending"),
            fraction: min(max((storedEffort ?? 0) / 100, 0), 1),
            stops: scaleStops(scale),
            note: targetNote(
                effort: displayEffort,
                target: target,
                targetDay: targetDay?.day,
                targetIsCurrent: targetIsCurrent),
            activities: todayWorkouts.enumerated().map { index, row in
                mappedActivity(row, index: index, scale: scale)
            },
            weekLoad: week.values,
            weekDays: week.labels,
            weekHighlighted: weekHighlighted,
            weekVerdict: weekVerdict(rows: week.rows, scale: scale),
            weekCeiling: scale == .whoop ? 21 : 100,
            headline: effortHeadline(
                effort21: storedEffort.map { UnitFormatter.effortValue($0, scale: .whoop) },
                target21: target21,
                targetIsCurrent: targetIsCurrent)
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

    private static func targetNote(
        effort: Double?,
        target: ClosedRange<Double>?,
        targetDay: String?,
        targetIsCurrent: Bool
    ) -> String {
        guard let target else {
            return String(localized: "Charge is still calibrating. Your recovery-matched Effort range will appear when it is ready.")
        }
        if !targetIsCurrent {
            let date = targetDay.map(shortDateLabel) ?? String(localized: "an earlier day")
            let effortText = effort.map { String(localized: "Today’s Effort is \(format($0)).") }
                ?? String(localized: "Today’s Effort has not been scored yet.")
            return String(localized: "\(effortText) The \(format(target.lowerBound))–\(format(target.upperBound)) range comes from your latest scored Charge on \(date); no new target is available yet.")
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
        target21: ClosedRange<Int>?,
        targetIsCurrent: Bool
    ) -> String {
        guard let effort21 else { return String(localized: "No Effort scored yet") }
        guard let target21, targetIsCurrent else { return String(localized: "Effort so far today") }
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
            let rows = Array(history.filter { $0.day <= anchorKey && $0.strain != nil }.suffix(7))
            return (
                rows.compactMap { $0.strain.map { UnitFormatter.effortValue($0, scale: scale) } },
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
        let rows = keys.compactMap { key -> DailyMetric? in
            guard let row = byDay[key], row.strain != nil else { return nil }
            return row
        }
        return (
            rows.compactMap { $0.strain.map { UnitFormatter.effortValue($0, scale: scale) } },
            rows.map { dayLabel($0.day) },
            rows
        )
    }

    /// Axis anchors only. The earlier labels (Minimal/Moderate/All out at 8/52/92) looked scientific but
    /// had no model behind those cutoffs.
    private static func scaleStops(_ scale: EffortScale) -> [(label: String, position: Double)] {
        let maximum = scale == .whoop ? 21.0 : 100.0
        return [
            (label: "0", position: 0),
            (label: format(maximum / 2), position: 50),
            (label: format(maximum), position: 100),
        ]
    }

    @MainActor
    static func weekTargetCounts(
        rows: [DailyMetric],
        scale: EffortScale
    ) -> (recorded: Int, comparable: Int, inRange: Int, below: Int, above: Int) {
        let recorded = rows.compactMap { row -> (effort: Double, target: ClosedRange<Double>?)? in
            guard let strain = row.strain else { return nil }
            let target = CoupledView.optimalStrainRange(recovery: row.recovery).map {
                displayRange($0, scale: scale)
            }
            return (UnitFormatter.effortValue(strain, scale: scale), target)
        }
        let comparable = recorded.compactMap { row -> (Double, ClosedRange<Double>)? in
            guard let target = row.target else { return nil }
            return (row.effort, target)
        }
        // Classify each day against that day's own recovery-matched target. Averaging efforts and
        // target bounds separately lets a very high day cancel a very low one into a false "Balanced"
        // verdict, even when no individual day was in range.
        let below = comparable.filter { $0.0 < $0.1.lowerBound }.count
        let above = comparable.filter { $0.0 > $0.1.upperBound }.count
        let inRange = comparable.count - below - above
        return (recorded.count, comparable.count, inRange, below, above)
    }

    @MainActor
    private static func weekVerdict(rows: [DailyMetric], scale: EffortScale) -> String {
        let counts = weekTargetCounts(rows: rows, scale: scale)
        guard counts.recorded > 0 else { return String(localized: "No recorded Effort") }
        guard counts.comparable > 0 else {
            return String(localized: "\(counts.recorded) recorded days · no recovery targets")
        }
        return String(localized: "\(counts.inRange) of \(counts.comparable) target days in range · \(counts.below) below · \(counts.above) above")
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

    private static func shortDateLabel(_ day: String) -> String {
        guard let date = dayParser.date(from: day) else { return day }
        return shortDateFormatter.string(from: date)
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
        // Use the locale's abbreviated weekday rather than a one-letter initial. In English,
        // narrow symbols make both Tuesday/Thursday "T" and Saturday/Sunday "S", which turns a
        // seven-day chart into an ambiguous label sequence and cannot be repaired in a string
        // catalog. DateFormatter keeps this correct for every selected app language.
        formatter.setLocalizedDateFormatFromTemplate("EEE")
        return formatter
    }()

    private static let fullWeekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = AppLanguage.activeLocale
        formatter.setLocalizedDateFormatFromTemplate("EEEE")
        return formatter
    }()

    private static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = AppLanguage.activeLocale
        formatter.setLocalizedDateFormatFromTemplate("dMMM")
        return formatter
    }()
}
#endif
