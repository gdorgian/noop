#if os(iOS)
import SwiftUI
import StrandDesign

// MARK: - Aura Age
//
// Three readings, one screen, each labelled for what it actually claims.
//
//   Body Age    — the headline. A mortality-hazard sum over resting HR, cardiorespiratory fitness,
//                 sleep duration and regularity, nocturnal HRV against the age norm, and steps.
//                 This is the WHOOP-Age-shaped number: it moves with behaviour and it can name the
//                 factors moving it.
//   Fitness Age — a cardiorespiratory comparison expressed in years. Explicitly NOT a biological age,
//                 and its own disclaimer says so. Kept beneath the headline rather than blended into
//                 it, because averaging two numbers that answer different questions produces a third
//                 that answers neither.
//   VO₂max      — the estimate underneath both, shown so the wearer can see the input rather than
//                 only its consequences.
//
// Every number here is weekly and lands on a Saturday. That is the engines' own cadence, not a
// presentation choice: the inputs are 7-day medians, so a daily readout would be showing noise.
//
// The honesty rules this screen keeps:
//   • No number appears without its ± band. Both engines publish one; hiding it would be a claim to
//     precision neither model has.
//   • A missing reading says what is missing and how far off it is, never an em-dash alone.
//   • The drivers are the model's own signed contributions, not a re-derived narrative.

struct AuraAgeView: View {
    private let reading: AuraAgeReading

    init(reading: AuraAgeReading = .prototype) {
        self.reading = reading
    }

    var body: some View {
        VStack(spacing: AuraPalette.cardGap) {
            if reading.isReady {
                headline
                driversCard
                if !reading.history.isEmpty { trendCard }
                fitnessCard
                AuraReadCard(overline: String(localized: "The read"), text: reading.read)
            } else {
                notReadyCard
            }
            AuraInfoBanner(text: reading.disclaimer, accent: AuraPalette.textQuiet)
        }
    }

    // MARK: Headline

    private var headline: some View {
        VStack(spacing: 6) {
            Text(reading.bodyAgeOverline).auraOverline()
                .padding(.bottom, 10)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(reading.bodyAge)
                    .font(.system(size: 68, weight: .light, design: .rounded))
                    .foregroundStyle(AuraPalette.textPrimary)
                    .monospacedDigit()
                Text(reading.bodyAgeUnit)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(AuraPalette.textSecondary)
            }

            Text(reading.bodyAgeBand)
                .font(.system(size: 12.5))
                .foregroundStyle(AuraPalette.textFaint)

            Text(reading.delta)
                .font(.system(size: 15.5, weight: .medium))
                .multilineTextAlignment(.center)
                .foregroundStyle(reading.deltaTint)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 18)
        .padding(.vertical, 26)
        .auraCard()
    }

    // MARK: Drivers

    private var driversCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            AuraCardHeader(title: String(localized: "What's moving it"),
                           note: reading.driversNote)
                .padding(.horizontal, 2)
                .padding(.bottom, 14)

            ForEach(Array(reading.drivers.enumerated()), id: \.element.id) { index, driver in
                driverRow(driver, showsDivider: index < reading.drivers.count - 1)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .auraCard()
    }

    /// A signed contribution, drawn as a bar that leaves centre in the direction it pushes. Direction is
    /// carried by the label and the side the bar sits on, never by colour alone — a wearer who cannot
    /// separate the two hues still reads "adds years" / "takes years off" from the text.
    private func driverRow(_ driver: AuraAgeReading.Driver, showsDivider: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text(driver.label)
                    .font(.system(size: 15))
                    .foregroundStyle(AuraPalette.textPrimary)
                Spacer(minLength: 8)
                Text(driver.effect)
                    .font(.system(size: 13.5, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(driver.isProtective ? AuraPalette.accent : AuraPalette.effort)
            }
            .padding(.bottom, 8)

            GeometryReader { geo in
                let half = geo.size.width / 2
                let width = max(2, half * driver.magnitude)
                ZStack(alignment: .leading) {
                    Capsule().fill(AuraPalette.track).frame(height: 3)
                    Capsule()
                        .fill(driver.isProtective ? AuraPalette.accent : AuraPalette.effort)
                        .frame(width: width, height: 3)
                        .offset(x: driver.isProtective ? half - width : half)
                }
            }
            .frame(height: 3)

            if showsDivider {
                Rectangle().fill(AuraPalette.cardBorder).frame(height: 1).padding(.top, 14)
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(driver.label), \(driver.effect)"))
    }

    // MARK: Trend

    private var trendCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            AuraCardHeader(title: String(localized: "Body Age over time"),
                           note: reading.historyNote)
                .padding(.horizontal, 2)
                .padding(.bottom, 16)

            AuraTrendChart(
                values: reading.history,
                labels: reading.historyLabels,
                selected: max(reading.history.count - 1, 0),
                window: reading.historyWindow,
                onSelect: { _ in }
            )
            .frame(height: 132)
            .allowsHitTesting(false)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .auraCard()
    }

    // MARK: Fitness Age + VO₂max

    private var fitnessCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            AuraCardHeader(title: String(localized: "Fitness Age"),
                           note: reading.fitnessNote)
                .padding(.horizontal, 2)
                .padding(.bottom, 14)

            HStack(spacing: 8) {
                AuraStatTile(label: String(localized: "Fitness Age"),
                             value: reading.fitnessAge, unit: reading.fitnessAgeUnit,
                             valueTint: AuraPalette.rest)
                AuraStatTile(label: String(localized: "VO₂max"),
                             value: reading.vo2max, unit: reading.vo2maxUnit,
                             valueTint: AuraPalette.accent)
            }
            .padding(.bottom, 12)

            Text(reading.fitnessCaveat)
                .font(.system(size: 13))
                .lineSpacing(2)
                .foregroundStyle(AuraPalette.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .auraCard()
    }

    // MARK: Not ready

    /// The readiness path is the one most likely to be seen on a fresh install, so it gets the same care
    /// as the ready one: what is missing, whether it blocks the number, and how far off it is.
    private var notReadyCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            AuraCardHeader(title: String(localized: "Not enough yet"),
                           note: reading.readinessNote)
                .padding(.horizontal, 2)
                .padding(.bottom, 8)

            Text(reading.readinessLead)
                .font(.system(size: 14.5))
                .lineSpacing(2)
                .foregroundStyle(AuraPalette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 2)
                .padding(.bottom, 16)

            ForEach(Array(reading.readiness.enumerated()), id: \.element.id) { index, item in
                AuraListRow(key: item.label,
                            value: item.statusText,
                            subtitle: item.detail.isEmpty ? nil : item.detail,
                            showsDivider: index < reading.readiness.count - 1)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .auraCard()
    }
}

// MARK: - Reading

struct AuraAgeReading {
    struct Driver: Identifiable {
        let id: String
        let label: String
        /// The signed effect in words, e.g. "−1.4 yr" — carries direction without relying on the tint.
        let effect: String
        let isProtective: Bool
        /// 0…1 against the largest driver present, for the bar only.
        let magnitude: Double
    }

    /// One of SuperAgeCore's five weighted domains. Separate from `Driver`: a driver is a signed push
    /// on Body Age, a domain is a 0–100 standing in one area of health. They are not the same axis and
    /// must not be drawn as if they were.
    struct Domain: Identifiable {
        let id: String
        let label: String
        /// 0…100.
        let score: Double
        /// The domain's share of the overall score, e.g. "28%".
        let weight: String
    }

    struct ReadinessItem: Identifiable {
        let id: String
        let label: String
        let statusText: String
        let detail: String
    }

    let isReady: Bool

    let bodyAgeOverline: String
    let bodyAge: String
    let bodyAgeUnit: String
    let bodyAgeBand: String
    let delta: String
    let deltaTint: Color

    let drivers: [Driver]
    let driversNote: String

    let history: [Double]
    let historyLabels: [String]
    let historyWindow: ClosedRange<Double>
    let historyNote: String

    let fitnessAge: String
    let fitnessAgeUnit: String
    let vo2max: String
    let vo2maxUnit: String
    let fitnessNote: String
    let fitnessCaveat: String

    /// The five-domain breakdown, empty when there is not enough evidence to score one.
    let domains: [Domain]
    /// How complete the evidence was, e.g. "14 of 28 instruments · moderate confidence".
    let domainsNote: String

    let readiness: [ReadinessItem]
    let readinessNote: String
    let readinessLead: String

    let read: String
    let disclaimer: String

    /// The design prototype's values. Not live data — used by isolated previews and the simulator's
    /// `--aura-prototype` visual-regression seam.
    static let prototype = AuraAgeReading(
        isReady: true,
        bodyAgeOverline: String(localized: "Body Age"),
        bodyAge: "34",
        bodyAgeUnit: String(localized: "years"),
        bodyAgeBand: String(localized: "± 5 yr · updated Saturday"),
        delta: String(localized: "6 years younger than your age"),
        deltaTint: AuraPalette.accent,
        drivers: [
            Driver(id: "vo2max", label: String(localized: "Cardio fitness"),
                   effect: "−2.4 yr", isProtective: true, magnitude: 1.0),
            Driver(id: "rhr", label: String(localized: "Resting heart rate"),
                   effect: "−1.6 yr", isProtective: true, magnitude: 0.67),
            Driver(id: "steps", label: String(localized: "Daily movement"),
                   effect: "−1.1 yr", isProtective: true, magnitude: 0.46),
            Driver(id: "hrv", label: String(localized: "Variability vs your age"),
                   effect: "−0.7 yr", isProtective: true, magnitude: 0.29),
            Driver(id: "sleep_regularity", label: String(localized: "Sleep regularity"),
                   effect: "+0.9 yr", isProtective: false, magnitude: 0.38),
        ],
        driversNote: String(localized: "6 of 6 inputs"),
        history: [37.2, 36.8, 36.1, 35.4, 35.0, 34.3],
        historyLabels: ["12 Jul", "19 Jul", "26 Jul", "2 Aug", "9 Aug", "16 Aug"],
        historyWindow: 30...42,
        historyNote: String(localized: "Weekly"),
        fitnessAge: "31",
        fitnessAgeUnit: String(localized: "yrs"),
        vo2max: "47.2",
        vo2maxUnit: "ml/kg/min",
        fitnessNote: String(localized: "± 5 yr"),
        fitnessCaveat: String(localized: "A cardiorespiratory comparison — how your estimated fitness compares to a typical person, expressed in years. It is not a biological age and carries no medical meaning."),
        domains: [
            Domain(id: "cardiovascular", label: String(localized: "Cardiovascular"), score: 74, weight: "28%"),
            Domain(id: "activity", label: String(localized: "Activity"), score: 68, weight: "24%"),
            Domain(id: "bodyComposition", label: String(localized: "Body composition"), score: 61, weight: "18%"),
            Domain(id: "recovery", label: String(localized: "Recovery"), score: 79, weight: "15%"),
            Domain(id: "lifestyle", label: String(localized: "Lifestyle"), score: 55, weight: "15%"),
        ],
        domainsNote: String(localized: "14 of 28 instruments · moderate confidence"),
        readiness: [],
        readinessNote: "",
        readinessLead: "",
        read: String(localized: "Your Body Age has come down about three years over six weeks, and cardio fitness is doing most of that work. Sleep regularity is the one factor still pushing the other way — it is also the cheapest one to change."),
        disclaimer: String(localized: "Estimates from your own wearable data, computed on this device. Not a medical assessment, a diagnosis, or a prediction about your health.")
    )
}
#endif
