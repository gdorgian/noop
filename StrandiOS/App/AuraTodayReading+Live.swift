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
        let name = displayName.trimmingCharacters(in: .whitespaces)

        let greeting: String
        if !name.isEmpty {
            greeting = String(localized: "Hi, \(name)")
        } else {
            switch hour {
            case ..<12:  greeting = String(localized: "Good morning")
            case ..<18:  greeting = String(localized: "Good afternoon")
            default:     greeting = String(localized: "Good evening")
            }
        }

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

        // Charge: the design's pillar carries HRV in ms, not the 0–100 score — the score is the orb.
        let hrv = day?.avgHrv
        let chargeValue = hrv.map { String(Int($0.rounded())) } ?? "—"
        let chargeFraction = hrv.map { min($0 / 120, 1) } ?? 0

        // Effort stays on today's own logical-day row, even when Charge/Rest carry the latest scored
        // night. Its number follows NOOP's existing display preference; the stored 0–100 value is intact.
        let effort = effortDay?.strain
        let effortValue = effort.map { UnitFormatter.effortDisplay($0, scale: effortScale) } ?? "—"
        let effortFraction = effort.map { min(max($0 / 100, 0), 1) } ?? 0

        func series(_ pick: (DailyMetric) -> Double?) -> [Double] {
            history.compactMap(pick)
        }

        let signals: [Signal] = [
            Signal(id: "hr", name: String(localized: "Heart rate"),
                   value: day?.restingHr.map(String.init) ?? "—", unit: "bpm",
                   systemImage: "heart", tint: AuraPalette.accent,
                   series: series { $0.restingHr.map(Double.init) }),
            Signal(id: "hrv", name: String(localized: "Variability"),
                   value: hrv.map { String(Int($0.rounded())) } ?? "—", unit: "ms",
                   systemImage: "waveform.path.ecg", tint: AuraPalette.accent,
                   series: series { $0.avgHrv }),
            Signal(id: "resp", name: String(localized: "Breathing"),
                   value: day?.respRateBpm.map { String(format: "%.1f", $0) } ?? "—", unit: "rpm",
                   systemImage: "lungs", tint: AuraPalette.rest,
                   series: series { $0.respRateBpm }),
            Signal(id: "sleep", name: String(localized: "Sleep"),
                   value: sleepMin.map { String(format: "%.1f", $0 / 60) } ?? "—", unit: "h",
                   systemImage: "moon", tint: AuraPalette.effort,
                   series: series { $0.totalSleepMin.map { $0 / 60 } }),
        ]

        // The banner states what the screen is actually reading, so a stale or absent night is visible
        // rather than implied by em-dashes the wearer has to notice.
        let banner: String
        if let sleepMin {
            banner = String(localized: "Read from your last night — \(Int(sleepMin)) minutes asleep.")
        } else {
            banner = String(localized: "Wear your strap overnight for a reading in the morning.")
        }

        return AuraTodayReading(
            greeting: greeting,
            headline: headline,
            profileName: name,
            initial: name.first.map { String($0).uppercased() } ?? "N",
            restValue: restValue,
            restFraction: restFraction,
            chargeValue: chargeValue,
            chargeFraction: chargeFraction,
            effortValue: effortValue,
            effortUnit: "/\(UnitFormatter.effortScaleMax(effortScale))",
            effortFraction: effortFraction,
            signals: signals,
            banner: banner
        )
    }
}
#endif
