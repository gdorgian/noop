#if os(iOS)
import Foundation
import StrandAnalytics
import WhoopStore

/// Your ages, measured, for the production shell (owner decision, 24 Sep): ONE engine —
/// `VitalityEngine` — for the hero, its band and its drivers, from one call per window through
/// `IntelligenceEngine.vitalityInputs`, the shared input builder. The stored weekly `body_age` series
/// is NOT read: it is written from a different input set (no VO₂max, the duration-proxy regularity),
/// so drawing it beside these drivers would put two engines' answers on one screen.
struct NoopAgesRecord {
    struct Driver: Equatable, Identifiable {
        let key: String
        let name: String
        /// Signed modelled years (negative takes years off).
        let years: Double
        var id: String { key }
    }

    /// The last seven days' result; nil until the engine has its three inputs and the age is the wearer's.
    var bodyAge: Double?
    var chronoAge: Int = 0
    var band: Double = VitalityEngine.bandYears
    var drivers: [Driver] = []
    /// Up to ten weekly results from the same engine, oldest → newest, with each week's last day.
    var history: [(end: Date, age: Double)] = []
    /// The stored weekly Fitness Age and VO₂max estimate — a separate question the design keeps apart.
    var fitnessAge: Double?
    var vo2max: Double?
    /// Number of usable factors in the current seven-day VitalityEngine window. This is the
    /// actual gate for this build, not the prototype BioAge model's 28-instrument fixture.
    var factorsAvailable = 0
    var buildReason: String {
        if !loaded { return "Checking recorded signals" }
        if chronoAge <= 0 { return "Confirm your profile" }
        return "\(min(factorsAvailable, VitalityEngine.minFactors)) of \(VitalityEngine.minFactors) model factors"
    }
    /// Each factor's engine input per week, oldest → newest, over 26 weeks (the six-month average and
    /// the driver's ten-week line), keyed like `Contribution.key`. Nil for a week without that input.
    var weeklyInputs: [String: [Double?]] = [:]
    var loaded = false

    /// A factor's input in the unit its driver screen prints.
    static func value(of key: String, in inputs: VitalityEngine.Inputs) -> Double? {
        switch key {
        case "rhr": inputs.restingHR
        case "vo2max": inputs.vo2max
        case "consistency": inputs.sleepConsistency.map { $0 * 100 }
        case "steps": inputs.steps.map { $0 / 1000 }
        case "hrv": inputs.rmssd
        case "sleep": inputs.sleepHours
        default: nil
        }
    }

    /// The design's scale for each factor: its two ends and the words under it. Nil for a factor the
    /// design does not draw (sleep duration), which then shows no scale.
    static func scale(for key: String) -> (min: String, max: String, words: String, unit: String)? {
        switch key {
        case "vo2max": ("30", "55", "ml/kg/min, estimated", "")
        case "consistency": ("40%", "100%", "consistency of sleep timing", "%")
        case "rhr": ("42 bpm", "78 bpm", "lower is better here", "")
        case "steps": ("2k", "14k", "thousand steps a day", "k")
        case "hrv": ("30 ms", "110 ms", "nocturnal HRV against the norm for your age", " ms")
        default: nil
        }
    }
    /// The design's driver names for the engine's factor keys.
    static func name(for key: String, fallback: String) -> String {
        switch key {
        case "vo2max": "Cardio fitness"
        case "consistency": "Sleep regularity"
        case "rhr": "Resting heart rate"
        case "steps": "Daily movement"
        case "hrv": "Variability vs your age"
        default: fallback
        }
    }

    /// "−2.9 yr" / "+0.9 yr".
    static func effect(_ years: Double) -> String {
        let magnitude = abs(years).formatted(.number.precision(.fractionLength(1)))
        return (years < 0 ? "\u{2212}" : "+") + magnitude + " yr"
    }

    /// A weekly result may only use an estimate that existed by that week's end. Series from
    /// `exploreSeries` are sorted by day; a single current estimate would leak future VO₂max into
    /// every historical Body Age and driver input.
    static func latestValue(in series: [(day: String, value: Double)],
                            from earliestDay: String, through latestDay: String) -> Double? {
        series.last { $0.day >= earliestDay && $0.day <= latestDay }?.value
    }
}

@MainActor
final class NoopAgesStore: ObservableObject {
    @Published private(set) var record = NoopAgesRecord()

    func load(from repo: Repository, profile: ProfileStore, now: Date = Date()) async {
        guard repo.loaded else { return }
        var next = NoopAgesRecord()
        // An unconfirmed profile's age is an example; an age model over it is not the wearer's.
        let dateOfBirth = profile.dateOfBirth
        let age = ProfileStore.years(from: dateOfBirth, to: now)
        guard UserDefaults.standard.bool(forKey: "noop.energy.profileConfirmed"), age > 0 else {
            next.loaded = true
            record = next
            return
        }
        let sex = profile.sex
        next.chronoAge = age
        // Fetch enough history for the 26-week driver trend, then select an as-of value for
        // each week. The existing 120-day lookback still bounds how long a prior estimate can
        // be carried forward; no week can borrow a later sample.
        let vo2Series = await repo.exploreSeries(key: "vo2max_est", source: "my-whoop", days: 310)
        let fitnessAgeSeries = await repo.exploreSeries(key: "fitness_age", source: "my-whoop", days: 120)
        let sessions = await repo.allSleepSessions()
        let calendar = Calendar.current
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.dateFormat = "yyyy-MM-dd"

        func asOf(_ series: [(day: String, value: Double)], endingOn end: Date) -> Double? {
            guard let start = calendar.date(byAdding: .day, value: -120, to: end) else { return nil }
            return NoopAgesRecord.latestValue(in: series, from: Repository.localDayKey(start),
                                              through: Repository.localDayKey(end))
        }
        next.vo2max = asOf(vo2Series, endingOn: now)
        next.fitnessAge = asOf(fitnessAgeSeries, endingOn: now)

        func inputs(endingOn end: Date) -> VitalityEngine.Inputs? {
            guard let start = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: end)) else { return nil }
            let ageAtEnd = ProfileStore.years(from: dateOfBirth, to: end)
            guard ageAtEnd > 0 else { return nil }
            let days = repo.days.filter { d in
                guard let date = parser.date(from: d.day) else { return false }
                return date >= start && date <= end
            }
            let from = Int(start.timeIntervalSince1970), to = Int(end.timeIntervalSince1970)
            let windowSessions = sessions.filter { $0.endTs >= from && $0.endTs <= to }
                .map { (start: $0.effectiveStartTs, end: $0.endTs) }
            return IntelligenceEngine.vitalityInputs(
                days: days, age: ageAtEnd, sex: sex, vo2max: asOf(vo2Series, endingOn: end),
                sleepSessions: windowSessions)
        }
        func result(endingOn end: Date) -> VitalityEngine.Result? {
            inputs(endingOn: end).flatMap(VitalityEngine.compute)
        }

        let currentInputs = inputs(endingOn: now)
        next.factorsAvailable = currentInputs.map { VitalityEngine.contributions($0).count } ?? 0
        if let now7 = currentInputs.flatMap(VitalityEngine.compute) {
            next.bodyAge = now7.bodyAge
            next.band = now7.bandYears
            next.drivers = now7.contributions
                .map { NoopAgesRecord.Driver(key: $0.key, name: NoopAgesRecord.name(for: $0.key, fallback: $0.label),
                                             years: VitalityEngine.ageEffectYears(for: $0)) }
                .sorted { abs($0.years) > abs($1.years) }
        }
        next.history = (0..<10).reversed().compactMap { weeksBack in
            guard let end = calendar.date(byAdding: .day, value: -7 * weeksBack, to: now),
                  let r = result(endingOn: end) else { return nil }
            return (end, r.bodyAge)
        }
        let weeks: [VitalityEngine.Inputs?] = (0..<26).reversed().map { weeksBack in
            calendar.date(byAdding: .day, value: -7 * weeksBack, to: now).flatMap(inputs(endingOn:))
        }
        for key in next.drivers.map(\.key) {
            next.weeklyInputs[key] = weeks.map { $0.flatMap { NoopAgesRecord.value(of: key, in: $0) } }
        }
        next.loaded = true
        record = next
    }
}
#endif
