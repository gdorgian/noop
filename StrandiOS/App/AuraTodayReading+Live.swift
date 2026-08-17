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
    /// The design's four states over NOOP's 0–100 Charge, at the thresholds its own `gaugeFraction`
    /// values imply (.16 / .38 / .60 / .84 → the midpoints between them).
    static func forCharge(_ pct: Double?) -> AuraBodyState {
        guard let pct else { return .ready }        // no reading: the neutral middle, never a verdict
        switch pct {
        case ..<27:  return .depleted
        case ..<49:  return .strained
        case ..<72:  return .ready
        default:     return .restored
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
        effortDay: DailyMetric?,
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
        switch hour {
        case ..<12:  headline = String(localized: "Here's your morning read")
        case ..<18:  headline = String(localized: "Here's where you stand")
        default:     headline = String(localized: "Here's how today went")
        }

        // Rest: the night's duration against an 8h reference, which is the fraction the design's bar
        // expresses. Not a goal or a judgement — just the scale the bar is drawn on.
        let sleepMin = day?.totalSleepMin
        let restValue = sleepMin.map { "\(Int($0) / 60)h \(Int($0) % 60)m" } ?? "—"
        let restFraction = sleepMin.map { min($0 / 480, 1) } ?? 0

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
            Signal(id: "hr", name: String(localized: "Heart rate"),
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
        if let sleepMin {
            banner = String(localized: "Read from your last night — \(durationText(sleepMin)) asleep.")
        } else {
            banner = String(localized: "Wear your strap overnight for a reading in the morning.")
        }
        let bodyCopy = truthfulBodyCopy(recovery: recovery, effortScale: effortScale)

        return AuraTodayReading(
            greeting: greeting,
            headline: headline,
            profileName: name,
            initial: name.first.map { String($0).uppercased() } ?? "N",
            restValue: restValue,
            restFraction: restFraction,
            chargeValue: chargeValue,
            chargeUnit: "%",
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
        effortScale: EffortScale
    ) -> (verdict: String, coaching: String, session: String, rationale: String) {
        guard let recovery else {
            return (
                String(localized: "Waiting for data"),
                String(localized: "Your next body read will appear after NOOP has a valid scored night."),
                String(localized: "No Effort target yet"),
                String(localized: "A recovery-matched target needs a valid Charge first.")
            )
        }

        let score = Int(recovery.rounded())
        let verdict: String
        let coaching: String
        switch recovery {
        case 72...:
            verdict = String(localized: "Well restored")
            coaching = String(localized: "Your Charge is \(score) today. You have room for a demanding day if you want it.")
        case 49..<72:
            verdict = String(localized: "Steady")
            coaching = String(localized: "Your Charge is \(score) today. Train as planned and let how you feel set the ceiling.")
        case 27..<49:
            verdict = String(localized: "Running warm")
            coaching = String(localized: "Your Charge is \(score) today. A lighter day better matches your current recovery.")
        default:
            verdict = String(localized: "Needs a day")
            coaching = String(localized: "Your Charge is \(score) today. Recovery is the useful priority.")
        }

        guard let target = CoupledView.optimalStrainRange(recovery: recovery) else {
            return (verdict, coaching, String(localized: "No Effort target yet"),
                    String(localized: "A recovery-matched target needs a valid Charge first."))
        }
        let lower = displayTarget(target.lowerBound, scale: effortScale)
        let upper = displayTarget(target.upperBound, scale: effortScale)
        return (
            verdict,
            coaching,
            String(localized: "Aim for Effort \(lower)–\(upper)"),
            String(localized: "Matched to today’s Charge of \(score). The activity is your choice.")
        )
    }

    private static func displayTarget(_ target21: Int, scale: EffortScale) -> String {
        guard scale == .hundred else { return String(target21) }
        return String(Int((Double(target21) / 21 * 100).rounded()))
    }
}
#endif
