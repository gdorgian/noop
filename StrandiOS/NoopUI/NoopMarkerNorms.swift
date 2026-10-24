import StrandAnalytics
import SwiftUI

// MARK: - Marker norms
//
// Where a reading sits against people of your age and sex, as named ranges. Each table is a published
// population reference, never derived from the app's own models:
//   • Resting heart rate — the YMCA resting-pulse chart by age group and sex, collapsed to five bands.
//   • Heart rate variability — nocturnal RMSSD median by age (the same anchors the Body Age model uses),
//     banded by ratio to it.
//   • VO₂ max — the FRIEND registry median by age and sex (Kaminsky et al.), banded by ratio to it.
//   • Body fat — the American Council on Exercise categories by sex.
//   • Sleep — the National Sleep Foundation's recommended hours by age.
//   • Steps — Tudor-Locke's daily step categories.
//   • Blood oxygen and breathing rate — the usual adult clinical ranges.
// A measure with no defensible reference (weight, lean mass) gets none and reads its direction instead.

struct NoopMarkerProfile {
    let age: Int
    /// "male", "female", or anything else for unstated.
    let sex: String

    static var current: NoopMarkerProfile? {
        let d = UserDefaults.standard
        guard let dob = d.object(forKey: "profile.dateOfBirth") as? Date else { return nil }
        let age = Calendar.current.dateComponents([.year], from: dob, to: Date()).year ?? 0
        guard age > 0 else { return nil }
        return NoopMarkerProfile(age: age, sex: d.string(forKey: "profile.sex") ?? "")
    }

    var isMale: Bool { sex.lowercased() == "male" }
    var isFemale: Bool { sex.lowercased() == "female" }
    var sexWord: String { isMale ? "males" : isFemale ? "females" : "adults" }
}

enum NoopMarkerNorms {
    struct Ranges {
        let zones: [NoopMetric.Zone]
        let scale: ClosedRange<Double>
        let caption: String
    }

    private static let best = NoopHTMLColor.green
    private static let good = Color(hex: 0x8FEFC0)
    private static let middle = NoopHTMLColor.inkSoft
    private static let low = NoopHTMLColor.warm
    private static let poor = NoopHTMLColor.red

    /// Ranges for a catalogue key in the units the sheet shows (hours for sleep), or nil.
    static func ranges(for key: String, profile: NoopMarkerProfile?) -> Ranges? {
        switch key {
        case "rhr": return profile.map(restingHeartRate)
        case "hrv": return profile.map(variability)
        case "vo2max", "vo2max_est": return profile.map(vo2max)
        case "body_fat": return profile.map(bodyFat)
        case "sleep_total_min": return sleep(profile)
        case "steps", "steps_est": return steps
        case "spo2": return spo2
        case "resp_rate": return breathing
        default: return nil
        }
    }

    // MARK: Tables

    /// YMCA resting pulse: per age group, the upper bound of Excellent (athlete + excellent), Good,
    /// Fair (above average + average) and Below average; above that is Poor.
    private static func restingHeartRate(_ p: NoopMarkerProfile) -> Ranges {
        let groups: [(ClosedRange<Int>, String)] = [(0...25, "18 - 25"), (26...35, "26 - 35"), (36...45, "36 - 45"),
                                                    (46...55, "46 - 55"), (56...65, "56 - 65"), (66...200, "65+")]
        let male: [[Double]] = [[62, 66, 74, 82], [62, 66, 75, 82], [63, 67, 76, 83], [64, 68, 77, 84], [62, 68, 76, 82], [62, 66, 74, 80]]
        let female: [[Double]] = [[66, 70, 79, 85], [65, 69, 77, 83], [65, 70, 79, 85], [66, 70, 78, 84], [65, 69, 78, 84], [65, 69, 77, 85]]
        let g = groups.firstIndex { $0.0.contains(p.age) } ?? 1
        let b: [Double] = p.isMale ? male[g] : p.isFemale ? female[g] : zip(male[g], female[g]).map { ($0 + $1) / 2 }
        return Ranges(zones: [
            .init(label: "Excellent", range: 30..<b[0], color: best),
            .init(label: "Good", range: b[0]..<b[1], color: good),
            .init(label: "Fair", range: b[1]..<b[2], color: middle),
            .init(label: "Below average", range: b[2]..<b[3], color: low),
            .init(label: "Poor", range: b[3]..<140, color: poor)
        ], scale: (b[0] - 12)...(b[3] + 10), caption: "Standardized for \(groups[g].1) \(p.sexWord)")
    }

    private static func variability(_ p: NoopMarkerProfile) -> Ranges {
        let n = VitalityEngine.rmssdNorm(forAge: Double(p.age))
        return Ranges(zones: [
            .init(label: "Low", range: 0..<(n * 0.7), color: poor),
            .init(label: "Below average", range: (n * 0.7)..<(n * 0.9), color: low),
            .init(label: "Average", range: (n * 0.9)..<(n * 1.15), color: middle),
            .init(label: "Good", range: (n * 1.15)..<(n * 1.5), color: good),
            .init(label: "Excellent", range: (n * 1.5)..<400, color: best)
        ], scale: (n * 0.5)...(n * 1.8), caption: "Against night-time HRV for age \(p.age)")
    }

    private static func vo2max(_ p: NoopMarkerProfile) -> Ranges {
        let n = VitalityEngine.vo2maxNorm(forAge: Double(p.age), sex: p.sex)
        return Ranges(zones: [
            .init(label: "Poor", range: 0..<(n * 0.8), color: poor),
            .init(label: "Fair", range: (n * 0.8)..<(n * 0.95), color: low),
            .init(label: "Good", range: (n * 0.95)..<(n * 1.1), color: middle),
            .init(label: "Excellent", range: (n * 1.1)..<(n * 1.25), color: good),
            .init(label: "Superior", range: (n * 1.25)..<120, color: best)
        ], scale: (n * 0.65)...(n * 1.4), caption: "Standardized for age \(p.age) \(p.sexWord)")
    }

    private static func bodyFat(_ p: NoopMarkerProfile) -> Ranges {
        let b: [Double] = p.isFemale ? [14, 21, 25, 32] : p.isMale ? [6, 14, 18, 25] : [10, 17.5, 21.5, 28.5]
        return Ranges(zones: [
            .init(label: "Essential", range: 0..<b[0], color: low),
            .init(label: "Athletic", range: b[0]..<b[1], color: best),
            .init(label: "Fit", range: b[1]..<b[2], color: good),
            .init(label: "Acceptable", range: b[2]..<b[3], color: middle),
            .init(label: "High", range: b[3]..<100, color: poor)
        ], scale: (b[0] - 4)...(b[3] + 8), caption: "Standardized for adult \(p.sexWord)")
    }

    private static func sleep(_ p: NoopMarkerProfile?) -> Ranges {
        let older = (p?.age ?? 30) >= 65
        let top = older ? 8.0 : 9.0
        return Ranges(zones: [
            .init(label: "Short", range: 0..<6, color: poor),
            .init(label: "Below recommended", range: 6..<7, color: low),
            .init(label: "Recommended", range: 7..<top, color: best),
            .init(label: "Long", range: top..<24, color: middle)
        ], scale: 4.5...(top + 1.5), caption: older ? "Recommended for adults 65+" : "Recommended for adults 18 - 64")
    }

    private static let steps = Ranges(zones: [
        .init(label: "Sedentary", range: 0..<5000, color: poor),
        .init(label: "Low active", range: 5000..<7500, color: low),
        .init(label: "Somewhat active", range: 7500..<10000, color: middle),
        .init(label: "Active", range: 10000..<12500, color: good),
        .init(label: "Highly active", range: 12500..<200_000, color: best)
    ], scale: 2500...15000, caption: "Daily step categories for adults")

    private static let spo2 = Ranges(zones: [
        .init(label: "Low", range: 0..<92, color: poor),
        .init(label: "Borderline", range: 92..<95, color: low),
        .init(label: "Normal", range: 95..<101, color: best)
    ], scale: 88...100, caption: "Usual range for adults during sleep")

    private static let breathing = Ranges(zones: [
        .init(label: "Low", range: 0..<12, color: low),
        .init(label: "Normal", range: 12..<20, color: best),
        .init(label: "High", range: 20..<60, color: poor)
    ], scale: 8...24, caption: "Usual resting range for adults")
}
