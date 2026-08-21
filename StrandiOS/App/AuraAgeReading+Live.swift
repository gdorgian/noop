#if os(iOS)
import SwiftUI
import StrandAnalytics
import SuperAgeCore
import StrandDesign
import WhoopStore

// MARK: - Aura Age, wired to real data
//
// Nothing is computed here. Both ages are written weekly by `IntelligenceEngine` under the computed
// `-noop` source, and this adapter reads them back and dresses them. The one live calculation is the
// driver breakdown, and it goes through `IntelligenceEngine.vitalityInputs` — the same builder the
// stored headline used — so the explanation can never disagree with the number it explains.
//
// The screen degrades on its own: no scored week produces the readiness checklist rather than zeros,
// and any single missing value renders as an em-dash beside the ones that are present.

extension AuraAgeReading {

    /// - Parameters:
    ///   - bodyAgeSeries: the `body_age` weekly series, oldest → newest.
    ///   - fitnessAgeSeries: the `fitness_age` weekly series, oldest → newest.
    ///   - vo2maxSeries: the `vo2max_est` weekly series, oldest → newest.
    ///   - days: the trailing daily rows the driver breakdown aggregates (the last 7 are used).
    static func live(
        bodyAgeSeries: [(day: String, value: Double)],
        fitnessAgeSeries: [(day: String, value: Double)],
        vo2maxSeries: [(day: String, value: Double)],
        days: [DailyMetric],
        sleepSessions: [(start: Int, end: Int)],
        domainResult: BioAge.DomainResult?,
        readiness: FitnessAgeReadiness,
        chronologicalAge: Int,
        sex: String
    ) -> AuraAgeReading {
        let bodyAge = bodyAgeSeries.last?.value
        let fitnessAge = fitnessAgeSeries.last?.value
        let vo2max = vo2maxSeries.last?.value

        // Ready means there is a stored Body Age to show. The Fitness Age readiness checklist is what
        // explains an absence, because both engines run off the same weekly gate.
        guard let bodyAge else {
            return notReady(readiness: readiness, chronologicalAge: chronologicalAge)
        }

        let delta = Double(chronologicalAge) - bodyAge
        let years = Int(abs(delta).rounded())
        let deltaText: String
        let deltaTint: Color
        switch (years, delta > 0) {
        case (0, _):
            deltaText = String(localized: "About your age")
            deltaTint = AuraPalette.textSecondary
        case (1, true):
            deltaText = String(localized: "1 year younger than your age")
            deltaTint = AuraPalette.accent
        case (_, true):
            deltaText = String(localized: "\(years) years younger than your age")
            deltaTint = AuraPalette.accent
        case (1, false):
            deltaText = String(localized: "1 year older than your age")
            deltaTint = AuraPalette.effort
        default:
            deltaText = String(localized: "\(years) years older than your age")
            deltaTint = AuraPalette.effort
        }

        let contributions = VitalityEngine.contributions(IntelligenceEngine.vitalityInputs(
            days: Array(days.suffix(7)), age: chronologicalAge, sex: sex, vo2max: vo2max,
            sleepSessions: sleepSessions))
        let drivers = Self.drivers(from: contributions)

        // The weekly rows are already Saturday-keyed; show the trailing ten so a run of weeks reads as a
        // direction rather than a single step.
        let history = Array(bodyAgeSeries.suffix(10))
        let values = history.map(\.value)
        let window: ClosedRange<Double>
        if let low = values.min(), let high = values.max() {
            // Never draw a flat line as a dramatic one: pad to at least a 6-year window so a stable
            // Body Age looks stable.
            let midpoint = (low + high) / 2
            let span = max(high - low, 6)
            window = (midpoint - span * 0.7)...(midpoint + span * 0.7)
        } else {
            window = 30...60
        }

        return AuraAgeReading(
            isReady: true,
            bodyAgeOverline: String(localized: "Body Age"),
            bodyAge: String(Int(bodyAge.rounded())),
            bodyAgeUnit: String(localized: "years"),
            bodyAgeBand: String(localized: "± \(Int(VitalityEngine.bandYears)) yr · updated weekly"),
            delta: deltaText,
            deltaTint: deltaTint,
            drivers: drivers,
            driversNote: contributions.isEmpty
                ? String(localized: "No inputs yet")
                : String(localized: "\(contributions.count) inputs"),
            history: values,
            historyLabels: history.map { Self.weekLabel($0.day) },
            historyWindow: window,
            historyNote: String(localized: "Weekly"),
            fitnessAge: fitnessAge.map { String(Int($0.rounded())) } ?? "—",
            fitnessAgeUnit: fitnessAge == nil ? "" : String(localized: "yrs"),
            vo2max: vo2max.map { String(format: "%.1f", $0) } ?? "—",
            vo2maxUnit: vo2max == nil ? "" : "ml/kg/min",
            fitnessNote: String(localized: "± \(Int(FitnessAgeEngine.displayBandYears)) yr"),
            fitnessCaveat: String(localized: "A cardiorespiratory comparison — how your estimated fitness compares to a typical person, expressed in years. It is not a biological age and carries no medical meaning."),
            domains: Self.domains(from: domainResult),
            domainsNote: Self.domainsNote(from: domainResult),
            readiness: [],
            readinessNote: "",
            readinessLead: "",
            read: Self.read(delta: delta, drivers: drivers, weeks: values.count),
            disclaimer: Self.disclaimer
        )
    }

    // MARK: Drivers

    private static func drivers(from contributions: [VitalityEngine.Contribution]) -> [Driver] {
        // The engine reports each factor as a signed log-hazard. Years is what the wearer reads, so
        // convert through the model's OWN mapping rather than inventing a second one: Body Age is the
        // hazard sum scaled into years, so a factor's share of the sum is its share of the offset.
        let total = contributions.map { abs($0.lnHazard) }.reduce(0, +)
        guard total > 0 else { return [] }
        let largest = contributions.map { abs($0.lnHazard) }.max() ?? 1

        return contributions
            .sorted { abs($0.lnHazard) > abs($1.lnHazard) }
            .map { contribution in
                // Negative log-hazard is protective; the engine's `deltaYears` is positive when younger,
                // so a protective factor takes years off.
                let years = contribution.lnHazard * VitalityEngine.bandYears
                let protective = contribution.lnHazard < 0
                return Driver(
                    id: contribution.key,
                    label: contribution.label,
                    effect: String(format: protective ? "−%.1f yr" : "+%.1f yr", abs(years)),
                    isProtective: protective,
                    magnitude: min(abs(contribution.lnHazard) / largest, 1)
                )
            }
    }

    // MARK: Domains

    private static func domains(from result: BioAge.DomainResult?) -> [Domain] {
        guard let result else { return [] }
        // Ordered by weight, heaviest first: the domain that moves the score most should be read first.
        return FitnessAgeDomain.allCases
            .filter { result.domainScores[$0] != nil }
            // Sort on the NUMERIC weight, not its formatted string — "9%" sorts above "28%" lexically.
            .sorted { $0.defaultWeight > $1.defaultWeight }
            .compactMap { domain -> Domain? in
                guard let score = result.domainScores[domain] else { return nil }
                return Domain(id: domain.rawValue,
                              label: Self.domainLabel(domain),
                              score: score.score,
                              weight: "\(Int((domain.defaultWeight * 100).rounded()))%")
            }
    }

    /// The evidence line. Both halves are stated because they answer different questions: the instrument
    /// count says how much was observed, the confidence says how much that is worth.
    private static func domainsNote(from result: BioAge.DomainResult?) -> String {
        guard let result else { return "" }
        let confidence: String
        switch result.confidence {
        case ..<0.4:  confidence = String(localized: "low confidence")
        case ..<0.7:  confidence = String(localized: "moderate confidence")
        default:      confidence = String(localized: "high confidence")
        }
        return String(localized: "\(result.metricsUsed) of \(result.totalPossibleMetrics) instruments · \(confidence)")
    }

    private static func domainLabel(_ domain: FitnessAgeDomain) -> String {
        switch domain {
        case .cardiovascular:  return String(localized: "Cardiovascular")
        case .activity:        return String(localized: "Activity")
        case .recovery:        return String(localized: "Recovery")
        case .bodyComposition: return String(localized: "Body composition")
        case .lifestyle:       return String(localized: "Lifestyle")
        }
    }

    // MARK: Copy

    /// The paragraph under the chart. It states only what the numbers on this screen support: the
    /// direction, the biggest protective factor, and the biggest one working against it.
    private static func read(delta: Double, drivers: [Driver], weeks: Int) -> String {
        guard !drivers.isEmpty else {
            return String(localized: "Your Body Age is recorded but no single factor stands out yet. A few more weeks of wear will separate them.")
        }
        let best = drivers.first { $0.isProtective }
        let worst = drivers.first { !$0.isProtective }

        var sentences: [String] = []
        if delta > 0.5 {
            sentences.append(String(localized: "Your Body Age is reading younger than your years."))
        } else if delta < -0.5 {
            sentences.append(String(localized: "Your Body Age is reading older than your years."))
        } else {
            sentences.append(String(localized: "Your Body Age is sitting close to your actual age."))
        }
        if let best {
            sentences.append(String(localized: "\(best.label) is doing the most for you."))
        }
        if let worst {
            sentences.append(String(localized: "\(worst.label) is the one factor pushing the other way — and usually the cheapest to change."))
        } else {
            sentences.append(String(localized: "Nothing measured is currently working against you."))
        }
        if weeks < 4 {
            sentences.append(String(localized: "With \(weeks) week(s) recorded, treat this as a starting point rather than a trend."))
        }
        return sentences.joined(separator: " ")
    }

    private static let disclaimer = String(localized: "Estimates from your own wearable data, computed on this device. Not a medical assessment, a diagnosis, or a prediction about your health.")

    // MARK: Not ready

    private static func notReady(readiness: FitnessAgeReadiness, chronologicalAge: Int) -> AuraAgeReading {
        let items = readiness.items.map { item in
            ReadinessItem(
                id: item.key,
                label: item.label,
                statusText: {
                    switch item.status {
                    case .satisfied: return String(localized: "Ready")
                    case .partial:   return String(localized: "Building")
                    case .missing:   return item.required
                        ? String(localized: "Needed")
                        : String(localized: "Optional")
                    }
                }(),
                detail: item.detail
            )
        }
        let lead: String
        if chronologicalAge <= 0 {
            lead = String(localized: "Set your date of birth in your profile — every age reading is measured against it.")
        } else {
            lead = String(localized: "Body Age is computed once a week from at least four scored nights. Wear your strap overnight and it will appear on its own.")
        }
        return AuraAgeReading(
            isReady: false,
            bodyAgeOverline: String(localized: "Body Age"),
            bodyAge: "—", bodyAgeUnit: "", bodyAgeBand: "",
            delta: "", deltaTint: AuraPalette.textSecondary,
            drivers: [], driversNote: "",
            history: [], historyLabels: [], historyWindow: 30...60, historyNote: "",
            fitnessAge: "—", fitnessAgeUnit: "", vo2max: "—", vo2maxUnit: "",
            fitnessNote: "", fitnessCaveat: "",
            domains: [], domainsNote: "",
            readiness: items,
            readinessNote: String(localized: "Weekly"),
            readinessLead: lead,
            read: "",
            disclaimer: disclaimer
        )
    }

    // MARK: Labels

    private static func weekLabel(_ day: String) -> String {
        guard let date = weekParser.date(from: day) else { return day }
        return weekFormatter.string(from: date)
    }

    private static let weekParser: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let weekFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = AppLanguage.activeLocale
        formatter.setLocalizedDateFormatFromTemplate("dMMM")
        return formatter
    }()
}
#endif
