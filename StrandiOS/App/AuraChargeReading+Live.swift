#if os(iOS)
import Foundation
import StrandAnalytics
import WhoopStore

extension AuraChargeReading {

    /// Formats the same DailyMetric row, folded baselines and RecoveryScorer drivers that NOOP's
    /// incumbent Charge breakdown uses. No score or contributor is recomputed by the design layer.
    static func live(
        day: DailyMetric?,
        history: [DailyMetric],
        stressSeries: [(day: String, value: Double)],
        restSeries: [(day: String, value: Double)]
    ) -> AuraChargeReading {
        let recentHRV = history.suffix(30).compactMap(\.avgHrv).filter { $0 > 0 }
        let hrvPoints = history.suffix(30).compactMap { row -> (day: String, value: Double)? in
            guard let value = row.avgHrv, value > 0 else { return nil }
            return (row.day, value)
        }
        let hrvBaseline = Baselines.foldHistory(history.map(\.avgHrv), cfg: Baselines.hrvCfg)
        let rhrBaseline = Baselines.foldHistory(
            history.map { $0.restingHr.map(Double.init) },
            cfg: Baselines.restingHRCfg
        )
        let respBaseline = Baselines.foldHistory(history.map(\.respRateBpm), cfg: Baselines.respCfg)

        let restByDay = Dictionary(restSeries.map { ($0.day, $0.value) }, uniquingKeysWith: { _, last in last })
        let restPct = day.flatMap { restByDay[$0.day] ?? Repository.dailyColumn(key: "sleep_performance", day: $0) }

        let canonicalDrivers: [ChargeDriver]
        if let day, let hrv = day.avgHrv, let rhr = day.restingHr, hrvBaseline.usable {
            canonicalDrivers = RecoveryScorer.chargeDrivers(
                hrv: hrv,
                rhr: Double(rhr),
                resp: day.respRateBpm,
                hrvBaseline: hrvBaseline,
                rhrBaseline: rhrBaseline.usable ? rhrBaseline : nil,
                respBaseline: respBaseline.usable ? respBaseline : nil,
                sleepPerf: restPct.map { $0 / 100 },
                skinTempDev: day.skinTempDevC
            )
        } else {
            canonicalDrivers = []
        }

        let drivers = canonicalDrivers.map {
            mappedDriver(
                $0,
                day: day,
                history: history,
                restPct: restPct,
                hrvBaseline: hrvBaseline,
                rhrBaseline: rhrBaseline,
                respBaseline: respBaseline
            )
        }

        let stress = StressModel(days: history, stored: stressSeries)
        let axisPoints = Array(hrvPoints.suffix(22))
        let hrvValues = axisPoints.map(\.value)
        let normalRange: ClosedRange<Double>? = hrvBaseline.usable
            ? (hrvBaseline.baseline - 1.253 * hrvBaseline.spread)...(hrvBaseline.baseline + 1.253 * hrvBaseline.spread)
            : nil

        return AuraChargeReading(
            variability: day?.avgHrv.map { String(format: "%.0f", $0) } ?? "—",
            variabilityCaption: axisPoints.isEmpty
                ? String(localized: "Nightly variability will appear after a valid sleep.")
                : String(localized: "Each point is one night. The shaded band is your personal normal across \(axisPoints.count) readings."),
            dayHigh: recentHRV.max().map { String(format: "%.0f", $0) } ?? "—",
            dayLow: recentHRV.min().map { String(format: "%.0f", $0) } ?? "—",
            stress: stress.map { stressLabel($0.band) } ?? "—",
            baseline: hrvBaseline.usable ? String(format: "%.0f", hrvBaseline.baseline) : "—",
            variabilitySeries: hrvValues,
            variabilityLabels: axisPoints.map { pointLabel($0.day) },
            variabilityWindow: chartWindow(values: hrvValues, normalRange: normalRange),
            variabilityNormalRange: normalRange,
            axis: axisLabels(axisPoints.map(\.day)),
            drivers: drivers,
            banner: chargeBanner(day: day, drivers: canonicalDrivers),
            headline: chargeHeadline(day?.recovery)
        )
    }

    private static func mappedDriver(
        _ driver: ChargeDriver,
        day: DailyMetric?,
        history: [DailyMetric],
        restPct: Double?,
        hrvBaseline: BaselineState,
        rhrBaseline: BaselineState,
        respBaseline: BaselineState
    ) -> AuraChargeReading.Driver {
        let range: (position: Double, baseline: Double)
        switch driver.label {
        case "Heart rate variability":
            range = rangePosition(
                value: day?.avgHrv,
                baseline: hrvBaseline.usable ? hrvBaseline.baseline : nil,
                history: history.suffix(30).compactMap(\.avgHrv)
            )
        case "Resting heart rate":
            range = rangePosition(
                value: day?.restingHr.map(Double.init),
                baseline: rhrBaseline.usable ? rhrBaseline.baseline : nil,
                history: history.suffix(30).compactMap { $0.restingHr.map(Double.init) }
            )
        case "Respiratory rate":
            range = rangePosition(
                value: day?.respRateBpm,
                baseline: respBaseline.usable ? respBaseline.baseline : nil,
                history: history.suffix(30).compactMap(\.respRateBpm)
            )
        case "Sleep quality":
            range = (restPct ?? 0, RecoveryScorer.sleepPerfCenter * 100)
        case "Skin temperature":
            range = rangePosition(
                value: day?.skinTempDevC,
                baseline: 0,
                history: history.suffix(30).compactMap(\.skinTempDevC) + [0]
            )
        default:
            range = (50, 50)
        }

        let measurement = splitMeasurement(driver.valueText)
        return AuraChargeReading.Driver(
            id: driver.label,
            name: driver.label,
            value: measurement.value,
            unit: measurement.unit,
            position: range.position,
            baseline: range.baseline,
            plain: sentenceCase(driver.verdict)
        )
    }

    private static func rangePosition(
        value: Double?,
        baseline: Double?,
        history: [Double]
    ) -> (position: Double, baseline: Double) {
        let values = history + [value, baseline].compactMap { $0 }
        guard let lo = values.min(), let hi = values.max(), hi - lo > 0.0001 else { return (50, 50) }
        func position(_ input: Double?) -> Double {
            guard let input else { return 50 }
            return min(max((input - lo) / (hi - lo) * 100, 0), 100)
        }
        return (position(value), position(baseline))
    }

    private static func chartWindow(
        values: [Double],
        normalRange: ClosedRange<Double>?
    ) -> ClosedRange<Double> {
        let candidates = values + [normalRange?.lowerBound, normalRange?.upperBound].compactMap { $0 }
        guard let lo = candidates.min(), let hi = candidates.max() else { return 0...100 }
        let padding = max((hi - lo) * 0.18, 3)
        return max(0, lo - padding)...(hi + padding)
    }

    private static func pointLabel(_ day: String) -> String {
        guard let date = dayParser.date(from: day) else { return day }
        return axisFormatter.string(from: date)
    }

    private static func axisLabels(_ dayKeys: [String]) -> [String] {
        guard !dayKeys.isEmpty else { return [] }
        let last = dayKeys.count - 1
        let indices = [0, last / 3, (last * 2) / 3, last]
        var seen = Set<Int>()
        return indices.compactMap { index in
            guard seen.insert(index).inserted,
                  let date = dayParser.date(from: dayKeys[index]) else { return nil }
            return axisFormatter.string(from: date)
        }
    }

    private static func splitMeasurement(_ text: String) -> (value: String, unit: String) {
        let parts = text.split(separator: " ", maxSplits: 1).map(String.init)
        return (parts.first ?? text, parts.count > 1 ? parts[1] : "")
    }

    private static func sentenceCase(_ text: String) -> String {
        guard let first = text.first else { return text }
        return first.uppercased() + text.dropFirst()
    }

    private static func stressLabel(_ band: StressBand) -> String {
        switch band {
        case .low: return String(localized: "Low")
        case .medium: return String(localized: "Moderate")
        case .high: return String(localized: "High")
        }
    }

    private static func chargeBanner(day: DailyMetric?, drivers: [ChargeDriver]) -> String {
        guard day?.recovery != nil else {
            return String(localized: "Charge is still calibrating. NOOP needs more valid nights before it can compare you with your own baseline.")
        }
        guard let strongest = drivers.first else {
            return String(localized: "Charge is available, but there are not enough complete inputs to explain its drivers yet.")
        }
        return String(localized: "\(strongest.label) was your strongest Charge driver: \(strongest.verdict).")
    }

    private static func chargeHeadline(_ recovery: Double?) -> String {
        guard let recovery else { return String(localized: "Charge is calibrating") }
        switch recovery {
        case 67...: return String(localized: "Your body is ready")
        case 34..<67: return String(localized: "Your body is steady")
        default: return String(localized: "Your body needs recovery")
        }
    }

    private static let dayParser: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let axisFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = AppLanguage.activeLocale
        formatter.setLocalizedDateFormatFromTemplate("dMMM")
        return formatter
    }()
}
#endif
