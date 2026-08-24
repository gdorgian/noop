#if os(iOS)
import SwiftUI
import StrandDesign
import WhoopStore

// MARK: - Aura Today, wired to real data
//
// `AuraTodayReading.prototype` is the design's fixed set, kept so the screen can be reviewed in all four
// body states without a strap. This is the substitution the prototype comment points at: the same struct,
// built from the wearer's own `DailyMetric`.
//
// Every field degrades on its own. A wearer with no scored night, no strap paired, or a partial night
// gets em-dashes and empty sparklines rather than the prototype's numbers — showing someone else's
// 7h 12m to a user who has not slept in the app yet is worse than showing nothing.

extension AuraBodyState {
    /// Maps NOOP's canonical RecoveryScorer bands onto the orb. We do not invent a fourth clinical band
    /// just because the visual component supports four colours.
    static func forCharge(_ pct: Double?) -> AuraBodyState {
        guard let pct else { return .ready }        // no reading: the neutral middle, never a verdict
        switch pct {
        case 67...:  return .restored
        case 34..<67: return .ready
        default:     return .strained
        }
    }
}

extension AuraTodayReading {

    /// Build the screen's values from the day's metrics and profile.
    ///
    /// - Parameters:
    ///   - day: the newest scored day, or nil before the first analytics pass.
    ///   - history: trailing days, oldest → newest, for the signal sparklines.
    ///   - displayName: the wearer's name, or empty.
    static func live(
        day: DailyMetric?,
        dayIsCurrent: Bool,
        effortDay: DailyMetric?,
        restPerformance: Double?,
        history: [DailyMetric],
        displayName: String,
        effortScale: EffortScale,
        now: Date = Date()
    ) -> AuraTodayReading {
        let hour = Calendar.current.component(.hour, from: now)
        let greeting: String
        switch hour {
        case ..<12:  greeting = String(localized: "Good morning")
        case ..<18:  greeting = String(localized: "Good afternoon")
        default:     greeting = String(localized: "Good evening")
        }
        let name = displayName.trimmingCharacters(in: .whitespaces)

        let headline: String
        if day != nil, !dayIsCurrent {
            headline = String(localized: "Here's your latest recorded read")
        } else {
            switch hour {
            case ..<12:  headline = String(localized: "Here's your morning read")
            case ..<18:  headline = String(localized: "Here's where you stand")
            default:     headline = String(localized: "Here's how today went")
            }
        }

        // Rest: the canonical 0–100 sleep-performance composite. The earlier Aura tile displayed sleep
        // duration over an arbitrary eight-hour bar, which visually implied a target that was not used by
        // the model. Duration remains in the evidence banner and Sleep signal below.
        let sleepMin = day?.totalSleepMin
        let restValue = restPerformance.map { String(Int($0.rounded())) } ?? "—"
        let restFraction = restPerformance.map { min(max($0 / 100, 0), 1) } ?? 0

        // Charge: show the actual 0–100 Charge score. An earlier Aura pass put HRV in this tile while
        // still labelling it "Charge"; HRV remains visible in Signals and on the Charge detail screen.
        let hrv = day?.avgHrv
        let recovery = day?.recovery
        let chargeValue = recovery.map { String(Int($0.rounded())) } ?? "—"
        let chargeFraction = recovery.map { min(max($0 / 100, 0), 1) } ?? 0

        // Effort stays on today's own logical-day row, even when Charge/Rest carry the latest scored
        // night. Its number follows NOOP's existing display preference; the stored 0–100 value is intact.
        let effort = effortDay?.strain
        let effortValue = effort.map { UnitFormatter.effortDisplay($0, scale: effortScale) } ?? "—"
        let effortFraction = effort.map { min(max($0 / 100, 0), 1) } ?? 0

        func labelledSeries(_ pick: (DailyMetric) -> Double?) -> ([Double], [String]) {
            let rows = history.compactMap { row -> (Double, String)? in
                guard let value = pick(row) else { return nil }
                return (value, detailDayLabel(row.day))
            }
            return (rows.map(\.0), rows.map(\.1))
        }

        let hrSeries = labelledSeries { $0.restingHr.map(Double.init) }
        let hrvSeries = labelledSeries { $0.avgHrv }
        let respSeries = labelledSeries { $0.respRateBpm }
        let sleepSeries = labelledSeries { $0.totalSleepMin.map { $0 / 60 } }

        let signals: [Signal] = [
            Signal(id: "hr", name: String(localized: "Resting heart rate"),
                   value: day?.restingHr.map(String.init) ?? "—", unit: "bpm",
                   systemImage: "heart", tint: AuraPalette.accent,
                   series: hrSeries.0, labels: hrSeries.1),
            Signal(id: "hrv", name: String(localized: "Variability"),
                   value: hrv.map { String(Int($0.rounded())) } ?? "—", unit: "ms",
                   systemImage: "waveform.path.ecg", tint: AuraPalette.accent,
                   series: hrvSeries.0, labels: hrvSeries.1),
            Signal(id: "resp", name: String(localized: "Breathing"),
                   value: day?.respRateBpm.map { String(format: "%.1f", $0) } ?? "—", unit: "rpm",
                   systemImage: "lungs", tint: AuraPalette.rest,
                   series: respSeries.0, labels: respSeries.1),
            Signal(id: "sleep", name: String(localized: "Sleep"),
                   value: sleepMin.map { String(format: "%.1f", $0 / 60) } ?? "—", unit: "h",
                   systemImage: "moon", tint: AuraPalette.effort,
                   series: sleepSeries.0, labels: sleepSeries.1),
        ]

        // The banner states what the screen is actually reading, so a stale or absent night is visible
        // rather than implied by em-dashes the wearer has to notice.
        let banner: String
        if let day, let sleepMin {
            // `day` can be a carried scored night while today's analytics are still pending (or after a
            // longer gap in wear). Stamp its real date instead of calling an arbitrarily old row "last
            // night".
            banner = String(localized: "Latest recorded night (\(detailDayLabel(day.day))) — \(durationText(sleepMin)) asleep.")
        } else {
            banner = String(localized: "Wear your strap overnight for a reading in the morning.")
        }
        let bodyCopy = truthfulBodyCopy(
            recovery: recovery,
            scoreDayLabel: day.map { detailDayLabel($0.day) },
            scoreIsCurrent: dayIsCurrent,
            effortScale: effortScale)

        return AuraTodayReading(
            greeting: greeting,
            headline: headline,
            profileName: name,
            initial: name.first.map { String($0).uppercased() } ?? "N",
            restValue: restValue,
            restUnit: "%",
            restFraction: restFraction,
            chargeValue: chargeValue,
            chargeUnit: "%",
            chargeAvailable: recovery != nil,
            chargeFraction: chargeFraction,
            effortValue: effortValue,
            effortUnit: "/\(UnitFormatter.effortScaleMax(effortScale))",
            effortFraction: effortFraction,
            signals: signals,
            banner: banner,
            verdict: bodyCopy.verdict,
            coaching: bodyCopy.coaching,
            session: bodyCopy.session,
            sessionRationale: bodyCopy.rationale
        )
    }

    private static func durationText(_ minutes: Double) -> String {
        let rounded = max(0, Int(minutes.rounded()))
        if rounded < 60 { return String(localized: "\(rounded)m") }
        return rounded % 60 == 0
            ? String(localized: "\(rounded / 60)h")
            : String(localized: "\(rounded / 60)h \(rounded % 60)m")
    }

    private static func detailDayLabel(_ day: String) -> String {
        guard let date = detailDayParser.date(from: day) else { return day }
        return detailDayFormatter.string(from: date)
    }

    private static let detailDayParser: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let detailDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = AppLanguage.activeLocale
        formatter.setLocalizedDateFormatFromTemplate("dMMM")
        return formatter
    }()

    /// Copy backed only by the recorded Charge and NOOP's established recovery-to-Effort mapping. It
    /// never claims an HRV direction, sleep streak, prior training streak, or workout modality that was
    /// not supplied to this adapter.
    private static func truthfulBodyCopy(
        recovery: Double?,
        scoreDayLabel: String?,
        scoreIsCurrent: Bool,
        effortScale: EffortScale
    ) -> (verdict: String, coaching: String, session: String, rationale: String) {
        guard let recovery else {
            return (
                String(localized: "Waiting for data"),
                String(localized: "Your next body read will appear after Noop Aura has a valid scored night."),
                String(localized: "No Effort target yet"),
                String(localized: "A recovery-matched target needs a valid Charge first.")
            )
        }

        let score = Int(recovery.rounded())
        let verdict: String
        let currentCoaching: String
        switch recovery {
        case 67...:
            verdict = String(localized: "High recovery")
            currentCoaching = String(localized: "Your Charge is \(score) today. You have room for a demanding day if you want it.")
        case 34..<67:
            verdict = String(localized: "Moderate recovery")
            currentCoaching = String(localized: "Your Charge is \(score) today. Let how you feel set the ceiling on activity.")
        default:
            verdict = String(localized: "Low recovery")
            currentCoaching = String(localized: "Your Charge is \(score) today. Recovery is the useful priority.")
        }
        let coaching = scoreIsCurrent
            ? currentCoaching
            : String(localized: "Your latest Charge is \(score), recorded \(scoreDayLabel ?? String(localized: "on an earlier day")). Treat it as history until a new night is scored.")

        guard let target = CoupledView.optimalStrainRange(recovery: recovery) else {
            return (verdict, coaching, String(localized: "No Effort target yet"),
                    String(localized: "A recovery-matched target needs a valid Charge first."))
        }
        let lower = displayTarget(target.lowerBound, scale: effortScale)
        let upper = displayTarget(target.upperBound, scale: effortScale)
        if scoreIsCurrent {
            return (
                verdict,
                coaching,
                String(localized: "Aim for Effort \(lower)–\(upper)"),
                String(localized: "Matched to today’s Charge of \(score). The activity is your choice.")
            )
        }
        return (
            verdict,
            coaching,
            String(localized: "Latest recorded target \(lower)–\(upper)"),
            String(localized: "Matched to the Charge recorded \(scoreDayLabel ?? String(localized: "on an earlier day")); no new target is available yet.")
        )
    }

    private static func displayTarget(_ target21: Int, scale: EffortScale) -> String {
        guard scale == .hundred else { return String(target21) }
        return String(Int((Double(target21) / 21 * 100).rounded()))
    }
}
#endif
