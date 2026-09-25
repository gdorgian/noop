#if os(iOS)
import Foundation
import StrandAnalytics
import WhoopStore

/// Today's measured record for the production shell.
///
/// Every value comes from the same seam another surface already uses, so Today cannot disagree with
/// it: the day anchor from `Repository.widgetAnchor` (the widgets and Live Activity), the stress curve
/// from `StressDayCurve.today` (the Stress widget), vitals banding from `BodyVitalSigns` (the Health
/// screen), the night from `NoopRestRecord` (the Rest tab) and energy from `EnergyEngine` behind the
/// same profile-confirmation gate the Energy screen and widget obey.
///
/// Deliberately absent: charge left and everything priced against it. Nothing in the app computes an
/// intraday charge, and morning recovery is not allowed to stand in for it.
struct NoopDayRecord {
    /// The night the "Last night" row describes, with the need it is measured against.
    var rest: NoopRestRecord = .loading
    /// Five-minute heart-rate means since the start of the waking day, for the day-so-far strip.
    var dayHR: [Double] = []
    /// When the day-so-far strip starts: the end of the newest night if it ended today, else midnight.
    var dayStart: Date?
    /// The same five-minute buckets with their start times, for the scrubbable day and the Heart chart.
    var dayHRPoints: [(ts: Int, bpm: Double, maxBpm: Double)] = []
    /// Where the latest scored stress hour sits on the 0–3 proxy. Nil when nothing has been scored.
    var stressLevel: Double?
    /// Today's hourly stress steps (0–3), earliest first. Nil for an hour with too little signal.
    var stressHours: [(start: Date, step: Int?)] = []
    /// Vitals with a band, and how many of them sit outside it. Nil when none could be banded.
    var vitalsBanded: Int = 0
    var vitalsOut: Int = 0
    var energy: DailyEnergySummary?
    var energyConfirmed = false
    /// When today's Svea brief was written, if one was.
    var briefWrittenAt: Date?
    /// The Vitals screen's five cards, in the design's order. A vital with no value is left out.
    var vitals: [NoopVital] = []
    /// The latest weekly Fitness Age and the calendar age it is read against. Nil until the engine has
    /// scored one and the profile's age is confirmed — an example birthday cannot anchor "under your own".
    var fitnessAge: (value: Double, chrono: Int)?
    var loaded = false

    /// The design's four steps for a 0–3 stress level.
    static let stressNames = ["Settled", "Engaged", "Pushed", "Overloaded"]

    static func stressStep(_ level: Double) -> Int { min(3, max(0, Int(level.rounded()))) }
}

@MainActor
final class NoopDayStore: ObservableObject {
    @Published private(set) var record = NoopDayRecord()

    func load(from repo: Repository, profile: ProfileStore, now: Date = Date()) async {
        guard repo.loaded else { return }
        var next = NoopDayRecord()
        let calendar = Calendar.current

        let sessions = await repo.allSleepSessions()
        let habitual = await repo.habitualMidsleepSec()
        next.rest = NoopRestRecord.build(days: repo.days, sessions: sessions.isEmpty ? repo.sleeps : sessions,
                                         habitualMidsleepSec: habitual, now: now, calendar: calendar)

        let midnight = calendar.startOfDay(for: now)
        let start: Date = {
            guard let woke = next.rest.latest?.endDate, woke >= midnight, woke < now else { return midnight }
            return woke
        }()
        next.dayStart = start
        let buckets = await repo.hrBuckets(from: Int(start.timeIntervalSince1970),
                                           to: Int(now.timeIntervalSince1970), bucketSeconds: 300)
        let clean = buckets.filter { $0.bpm.isFinite && $0.bpm > 0 }
        next.dayHR = clean.map(\.bpm)
        next.dayHRPoints = clean.map { ($0.ts, $0.bpm, $0.maxBpm) }

        if let stress = await StressDayCurve.today(repo: repo, now: now, calendar: calendar) {
            next.stressLevel = stress.result.timeline.last(where: { $0.level != nil })?.level
            next.stressHours = stress.result.hours.map {
                (Date(timeIntervalSince1970: TimeInterval($0.startTs)), $0.level.map(NoopDayRecord.stressStep))
            }
        }

        let readings = BodyVitalSigns.readings(sourceRows: repo.vitalMetricRows,
                                               temperatureUnit: .celsius, now: now)
            .filter { Self.todayVitalKeys.contains($0.key) }
        let banded = readings.filter { $0.banding.band != .noData }
        next.vitalsBanded = banded.count
        next.vitalsOut = banded.filter { $0.banding.band == .outOfRange }.count
        next.vitals = NoopVital.designOrder.compactMap { key in
            readings.first { $0.key == key }.flatMap(NoopVital.init(reading:))
        }

        if UserDefaults.standard.bool(forKey: "noop.energy.profileConfirmed"), profile.age > 0,
           let latest = await repo.exploreSeries(key: "fitness_age", source: "my-whoop", days: 60).last {
            next.fitnessAge = (latest.value, profile.age)
        }

        next.energyConfirmed = UserDefaults.standard.bool(forKey: "noop.energy.profileConfirmed")
        let dayKey = Repository.localDayKey(now)
        let day = repo.days.last { $0.day == dayKey }
        let end = calendar.date(byAdding: .day, value: 1, to: midnight) ?? midnight.addingTimeInterval(86_400)
        next.energy = EnergyEngine.summarize(
            .init(day: dayKey, strapTotalKcal: day?.activeKcalEst, steps: day?.steps),
            profile: UserProfile(weightKg: profile.weightKg, heightCm: profile.heightCm,
                                 age: Double(profile.age), sex: profile.sex,
                                 stepTicksPerStep: profile.stepTicksPerStep),
            context: .init(isToday: true, dayDurationSeconds: end.timeIntervalSince(midnight),
                           elapsedSeconds: now.timeIntervalSince(midnight))
        )

        if let written = UserDefaults(suiteName: WidgetSnapshot.suiteName)?
            .object(forKey: "coachBrief.widgetDate") as? Date,
           calendar.isDate(written, inSameDayAs: now) {
            next.briefWrittenAt = written
        }
        next.loaded = true
        record = next
    }

    /// The five signals the Vitals screen draws, by `BodyVitalSigns` key.
    static let todayVitalKeys: Set<String> = ["rhr", "hrv", "resp", "spo2", "skin"]
}

/// One Vitals card: the reading, the zone it was judged against and the scale the zone is drawn on,
/// following the final HTML's geometry (the band sits in the middle of a scale 0.8 of its width wider on
/// each side). The zone is the same one `VitalBands` used to call the value in or out — your own baseline
/// ± 2σ once it is trusted, the population range before that — so the dot and the count never disagree.
struct NoopVital: Equatable {
    let key: String
    let name: String
    let window: String
    let unit: String
    let decimals: Int
    let value: Double
    /// The personal baseline, only when the zone is personal. Nil draws no tick and no delta.
    let baseline: Double?
    let low: Double
    let high: Double
    let outside: Bool
    /// Which way is good: +1 higher, −1 lower, 0 neither (the HTML's `dir`).
    let direction: Int

    static let designOrder = ["rhr", "hrv", "resp", "spo2", "skin"]

    init?(reading: BodyVitalReading) {
        guard let value = reading.value, reading.banding.band != .noData else { return nil }
        let absoluteSkin = reading.key == "skin" && VitalBands.isAbsoluteSkinTemp(value)
        switch reading.key {
        case "rhr": (name, window, unit, decimals, direction) = ("Resting heart rate", "overnight average", "bpm", 0, -1)
        case "hrv": (name, window, unit, decimals, direction) = ("Heart rhythm", "overnight variability", "ms", 0, 1)
        case "resp": (name, window, unit, decimals, direction) = ("Breathing rate", "overnight average", "/min", 1, 0)
        case "spo2": (name, window, unit, decimals, direction) = ("Blood oxygen", "overnight average", "%", 0, 0)
        case "skin":
            (name, unit, decimals, direction) = ("Skin temperature", "\u{00B0}C", 1, 0)
            window = absoluteSkin ? "overnight average" : "deviation from your normal"
        default: return nil
        }
        key = reading.key
        self.value = value
        outside = reading.banding.band == .outOfRange
        if reading.banding.basis == .personal, let state = reading.personal, state.trusted {
            let reach = VitalBands.sigmaK * Baselines.sigma(state)
            baseline = state.baseline
            low = state.baseline - reach
            high = state.baseline + reach
        } else {
            baseline = nil
            let population: ClosedRange<Double> = switch reading.key {
            case "rhr": 40...60
            case "hrv": 40...120
            case "resp": 12...20
            case "spo2": 95...100
            default: absoluteSkin ? 33...36 : (-0.6)...0.6
            }
            low = population.lowerBound
            high = population.upperBound
        }
    }

    /// The drawn scale: the HTML's band-plus-0.8-widths, stretched to keep the dot on the track.
    var scale: ClosedRange<Double> {
        let width = max(high - low, 1e-6)
        var lo = low - width * 0.8, hi = high + width * 0.8
        lo = min(lo, value - width * 0.15)
        hi = max(hi, value + width * 0.15)
        if key == "spo2" { hi = min(hi, 100) }
        return lo...max(hi, lo + 1e-6)
    }

    func fraction(_ x: Double) -> Double {
        let s = scale
        return min(1, max(0, (x - s.lowerBound) / (s.upperBound - s.lowerBound)))
    }

    func format(_ x: Double) -> String {
        let text = String(format: "%.\(decimals)f", abs(x))
        return (x < 0 && text.contains(where: { $0 != "0" && $0 != "." }) ? "\u{2212}" : "") + text
    }

    /// "−2 bpm vs baseline" / "at your baseline"; nil without a personal baseline.
    var delta: String? {
        guard let baseline else { return nil }
        let diff = value - baseline
        if abs(diff) < (high - low) * 0.12 { return "at your baseline" }
        return (diff > 0 ? "+" : "\u{2212}") + format(abs(diff)) + " " + unit + " vs baseline"
    }

    /// The chip reads blue when the value sits in the zone on its good side, grey when on the other.
    var deltaIsGood: Bool {
        guard let baseline, !outside else { return false }
        let diff = value - baseline
        return direction == 0 || (direction > 0 ? diff >= 0 : diff <= 0)
    }

    /// The HTML's count line, over the vitals that could be judged.
    static func summary(_ vitals: [NoopVital]) -> String? {
        guard !vitals.isEmpty else { return nil }
        let words = ["none", "one", "two", "three", "four", "five"]
        let out = vitals.filter(\.outside).count, inZone = vitals.count - out
        let lead = words[inZone]
        return lead.prefix(1).uppercased() + lead.dropFirst() + " in your normal zone, " + words[out] + " outside it"
    }
}
#endif

#if os(iOS)
/// The Energy card's words and numbers for one engine summary, following the final HTML's five
/// designed readings (measured · learning · partial · steps · cold) and nothing in between. Shared by
/// Today's card and the Energy screen so the two cannot state different figures.
struct NoopEnergyReading: Equatable {
    enum Case: Equatable { case measured, learning, partial, steps, cold }
    struct Segment: Equatable { let fraction: Double; let kind: Kind }
    enum Kind: Equatable { case basal, active, basalSoft, activeSoft, hairline }

    let kind: Case
    let hero: String
    let heroNote: String
    let segments: [Segment]
    let legend: [(label: String, kind: Kind)]
    let projection: String
    let projectionIsLive: Bool
    let coverage: String
    /// Confidence chip label; nil when solid.
    let chip: String?
    let chipCalibrating: Bool
    /// The Energy screen's sentence under the hero; nil where the HTML's sentence names facts
    /// (an hour count, a gap's clock times) this reading cannot state.
    var lead: String? = nil
    /// The Energy screen's "What it read" rows: label, value, note.
    var rows: [(k: String, v: String, note: String)] = []

    static func == (a: Self, b: Self) -> Bool {
        a.kind == b.kind && a.hero == b.hero && a.heroNote == b.heroNote && a.projection == b.projection
            && a.coverage == b.coverage && a.chip == b.chip
    }

    /// Nil when the profile is unconfirmed or the engine produced nothing it can defend.
    static func make(_ summary: DailyEnergySummary?, confirmed: Bool, now: Date = Date(),
                     calendar: Calendar = .current) -> NoopEnergyReading? {
        guard confirmed, let s = summary else { return nil }
        let elapsedH = now.timeIntervalSince(calendar.startOfDay(for: now)) / 3600
        switch s.source {
        case .profileOnly:
            guard let bmr = s.estimatedBMR24h, bmr > 0 else { return nil }
            return .init(kind: .cold, hero: "about \(grouped(tens(bmr)))",
                         heroNote: "modelled for a full day at rest, from your profile",
                         segments: [.init(fraction: 1, kind: .hairline)],
                         legend: [("modelled basal, nothing measured", .hairline)],
                         projection: "No projection. There is nothing measured to project from, and Noop would rather say so than draw a line through one number.",
                         projectionIsLive: false,
                         coverage: "Wear the strap for a day and this becomes a reading rather than a model. Nothing here is waiting on a setting.",
                         chip: "no measured day yet", chipCalibrating: true,
                         lead: "Nothing has measured today yet. What is here is the one figure Noop can always stand behind: what a body your height, weight, age and sex spends doing nothing at all.",
                         rows: [("Read from", "Your profile only", "height, weight, age, sex. Nothing else is read"),
                                ("How much of the day it saw", "None of it", "which is why the figure is a model and says so"),
                                ("Unattributed heart rate", "\u{2014}", "there is no heart rate recorded today"),
                                ("The forecast\u{2019}s width", "\u{2014}", "no forecast is offered at all, rather than one with a width nobody could use")])
        case .stepsEstimate:
            guard let total = s.totalBurnedSoFar, total > 0 else { return nil }
            let band = (s.uncertaintyFraction ?? 0.30)
            let basal = s.basalBurnedSoFar ?? 0, active = s.activeBurnedSoFar ?? 0
            let projection = s.projectedRangeKcal.map {
                "Heading for \(fifties($0.lowerBound)) to \(fifties($0.upperBound)) by midnight, on the same steps."
            }
            return .init(kind: .steps,
                         hero: "\(fifties(total * (1 - band)))\u{2013}\(fifties(total * (1 + band)))",
                         heroNote: "a range, because steps are all it had to go on",
                         segments: split(basal, active, soft: true),
                         legend: [("basal, modelled", .basalSoft), ("active, from steps", .activeSoft)],
                         projection: projection ?? "",
                         projectionIsLive: projection != nil,
                         coverage: "Your phone counted the walking. Noop will not show you that count, and it is not a target \u{2014} it is only an input to this estimate.",
                         chip: "steps only", chipCalibrating: true,
                         lead: "No strap today, so the day is modelled from your phone\u{2019}s step data. That is a shape of a day rather than a measurement of one, and it is stated as a range.",
                         rows: [("Read from", "Your phone\u{2019}s step data", "named as a source. The count itself is never displayed"),
                                ("Unattributed heart rate", "\u{2014}", "no heart rate was recorded today, so there is none to attribute"),
                                ("The forecast\u{2019}s width", "\u{00B1}\(Int((band * 100).rounded()))%", "the widest band Noop will publish; below this it stops being a reading")])
        case .appleSplit, .strapWornTime, .mixed:
            guard let total = s.totalBurnedSoFar, total > 0 else { return nil }
            let basal = s.basalBurnedSoFar ?? 0, active = s.activeBurnedSoFar ?? 0
            let hasSplit = s.basalBurnedSoFar != nil && s.activeBurnedSoFar != nil && basal + active > 0
            let measuredH = (s.coverage.overall ?? 1) * elapsedH
            let missed = Int((elapsedH - measuredH).rounded())
            let seen = hoursWord(measuredH), all = hoursWord(elapsedH)
            let partial = missed >= 2
            let projection: String?
            if let r = s.projectedRangeKcal {
                projection = partial
                    ? "Heading for \(fifties(r.lowerBound)) to \(fifties(r.upperBound)) by midnight \u{2014} a wider range than usual, because it saw less of today."
                    : "Heading for \(fifties(r.lowerBound)) to \(fifties(r.upperBound)) by midnight, if the rest of the evening looks like the rest of your week."
            } else { projection = nil }
            let coverage: String
            switch missed {
            case ..<1: coverage = "\(capitalized(seen)) of the \(all) hours since midnight were measured."
            case 1: coverage = "\(capitalized(seen)) of the \(all) hours since midnight were measured. The one it missed is drawn, and counted as nothing."
            default: coverage = "\(capitalized(seen)) of the \(all) hours since midnight were measured. The \(hoursWord(Double(missed))) it missed are left out of the figure rather than filled in."
            }
            let covPct = "\(Int(((s.coverage.overall ?? 1) * 100).rounded()))%"
            let width = s.uncertaintyFraction.map { "\u{00B1}\(Int(($0 * 100).rounded()))%" }
            let unattributed = Self.minutes(s.unresolvedElevatedHRSeconds)
            let source: (String, String) = s.source == .appleSplit
                ? ("Apple Health", "") : ("The strap", partial ? "" : "by worn time, with Apple Health as the fallback")
            let rows: [(k: String, v: String, note: String)] = partial
                ? [("Read from", source.0, source.1),
                   ("How much of the day it saw", covPct, "and the band widens as it falls"),
                   ("Unattributed heart rate", unattributed, ""),
                   ("The forecast\u{2019}s width", width ?? "\u{2014}", width == nil ? "" : "wider today than on a full day, by the coverage term")]
                : [("Read from", source.0, source.1),
                   ("How much of the day it saw", covPct, "stated in hours on the card; the percentage lives here"),
                   ("Unattributed heart rate", unattributed, "elevated and not matched to a session, so it is counted as active and named here"),
                   projection != nil && width != nil
                    ? ("The forecast\u{2019}s width", width!, "widens as coverage falls")
                    : ("The forecast\u{2019}s width", "\u{2014}", "no forecast yet, so there is no width to state")]
            return .init(kind: partial ? .partial : (projection == nil ? .learning : .measured),
                         hero: grouped(tens(total)),
                         heroNote: partial
                            ? "spent in the \(seen) hours it saw \u{2014} the gap is not in this figure"
                            : "spent in the hours it measured, basal and active together",
                         // The strap writes one whole-day total with no basal/active split; an unknown
                         // split is left out rather than drawn as two zeros.
                         segments: hasSplit ? split(basal, active, soft: false) : [],
                         legend: hasSplit ? [("basal \(grouped(tens(basal)))", .basal), ("active \(grouped(tens(active)))", .active)] : [],
                         projection: projection ?? "",
                         projectionIsLive: projection != nil,
                         coverage: coverage,
                         chip: partial ? "\(seen) of \(all) hours" : nil,
                         chipCalibrating: false,
                         lead: !partial && missed == 1
                            ? "Measured from the strap, which you have worn for all but one hour of the day so far." : nil,
                         rows: rows)
        }
    }

    private static func split(_ basal: Double, _ active: Double, soft: Bool) -> [Segment] {
        let total = max(1, basal + active)
        return [.init(fraction: basal / total, kind: soft ? .basalSoft : .basal),
                .init(fraction: active / total, kind: soft ? .activeSoft : .active)]
    }

    /// "1 h 10 m", "24 m" — the HTML's unattributed-time format.
    static func minutes(_ seconds: Int) -> String {
        let m = max(0, seconds) / 60
        return m >= 60 ? "\(m / 60) h \(m % 60) m" : "\(m) m"
    }

    static func tens(_ v: Double) -> Int { Int((v / 10).rounded()) * 10 }
    static func grouped(_ v: Int) -> String { v.formatted(.number.grouping(.automatic)) }
    static func fifties(_ v: Double) -> String { grouped(Int((v / 50).rounded()) * 50) }

    private static let words = ["no", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine",
        "ten", "eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen", "seventeen",
        "eighteen", "nineteen", "twenty", "twenty-one", "twenty-two", "twenty-three", "twenty-four"]
    static func hoursWord(_ h: Double) -> String {
        let r = Int(h.rounded()); return words.indices.contains(r) ? words[r] : "\(r)"
    }
    private static func capitalized(_ s: String) -> String { s.prefix(1).uppercased() + s.dropFirst() }
}
#endif
