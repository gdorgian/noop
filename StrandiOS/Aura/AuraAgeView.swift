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
// Body Age, Fitness Age and VO₂max are weekly and land on a Saturday. The separately labelled current
// health-domain card is a live 30-day coverage view and must not be read as part of that stored snapshot.
//
// The honesty rules this screen keeps:
//   • Estimates are labelled as estimates and keep their readiness/missing-data states. The model's
//     legacy ±5 presentation band is not shown as though it were a validated confidence interval.
//   • A missing reading says what is missing and how far off it is, never an em-dash alone.
//   • The drivers are the model's own signed contributions, not a re-derived narrative.

struct AuraAgeView: View {
    private let reading: AuraAgeReading

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var motion = NoopMotionState.shared

    init(reading: AuraAgeReading) {
        self.reading = reading
    }

    private var poseStill: Bool { motion.poseStill(reduceMotion) }

    var body: some View {
        VStack(spacing: 12) {
            if reading.isReady {
                ageSummary
                bodyAgeCard
                driversCard
                if !reading.history.isEmpty { trendCard }
                fitnessCard
                domainsSection
                readCard
            } else {
                notReadyHero
                notReadyCard
            }
            disclaimer
        }
    }

    // MARK: Summary

    private var ageSummary: some View {
        VStack(spacing: 12) {
            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(String(localized: "Weekly"))
                        .font(AgeDesign.number(23, weight: .light))
                        .foregroundStyle(AgeDesign.mint)
                    Text(String(localized: "stored snapshot"))
                        .font(AgeDesign.ui(9.5, weight: .semibold))
                        .tracking(1.2)
                        .textCase(.uppercase)
                        .foregroundStyle(AuraPalette.textQuiet)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                BodyAgeAura(value: reading.bodyAge, available: true, reduceMotion: poseStill)
                    .frame(width: 138, height: 138)

                VStack(alignment: .trailing, spacing: 5) {
                    Text(String(localized: "Not calculated"))
                        .font(AgeDesign.ui(11.5, weight: .medium))
                        .foregroundStyle(AuraPalette.textDim)
                        .multilineTextAlignment(.trailing)
                    Text(String(localized: "pace of aging"))
                        .font(AgeDesign.ui(9.5, weight: .semibold))
                        .tracking(1.2)
                        .textCase(.uppercase)
                        .foregroundStyle(AuraPalette.textQuiet)
                        .multilineTextAlignment(.trailing)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }

            Text(reading.delta)
                .font(AgeDesign.number(26, weight: .light))
                .tracking(-0.7)
                .lineSpacing(2)
                .foregroundStyle(AuraPalette.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("Pace of aging is not calculated from the current snapshot"))
    }

    // MARK: Body Age

    /// The prototype draws a ±5 band. The production model does not expose a validated confidence
    /// interval, so the shipped surface keeps the exact weekly value and the adapter's own status line
    /// without turning that presentation convention into scientific certainty.
    private var bodyAgeCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(reading.bodyAgeOverline)
                    .font(AgeDesign.ui(10, weight: .semibold))
                    .tracking(1.4)
                    .textCase(.uppercase)
                    .foregroundStyle(AuraPalette.textFaint)
                Spacer()
                Text(String(localized: "Updated weekly"))
                    .font(AgeDesign.ui(11))
                    .foregroundStyle(AuraPalette.textDim)
            }

            HStack(alignment: .lastTextBaseline, spacing: 10) {
                Text(reading.bodyAge)
                    .font(AgeDesign.number(76, weight: .ultraLight))
                    .tracking(-3.2)
                    .monospacedDigit()
                    .foregroundStyle(AuraPalette.textPrimary)
                VStack(alignment: .leading, spacing: 4) {
                    Text(reading.bodyAgeUnit)
                        .font(AgeDesign.ui(13))
                        .foregroundStyle(AuraPalette.textSecondary)
                    Text(reading.delta)
                        .font(AgeDesign.ui(11.5, weight: .semibold))
                        .foregroundStyle(reading.deltaTint)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.bottom, 8)
            }

            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AgeDesign.mint)
                Text(reading.bodyAgeBand)
                    .font(AgeDesign.ui(11.5))
                    .foregroundStyle(AuraPalette.textQuiet)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 9)
            .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            Text(String(localized: "No confidence band is shown because this model does not expose a validated confidence interval."))
                .font(AgeDesign.ui(11.5))
                .lineSpacing(3)
                .foregroundStyle(AuraPalette.textQuiet)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .background(ageCard(radius: 24))
        .accessibilityElement(children: .combine)
    }

    // MARK: Domains

    /// The five weighted domains, from a second and independent scorer.
    ///
    /// Drawn deliberately UNLIKE the drivers above. A driver is a signed push on Body Age and leaves a
    /// centre line in one of two directions; a domain is a 0–100 standing that fills from the left. They
    /// are different axes, and drawing them the same way would invite reading a high activity score as
    /// "activity is taking years off", which it does not say.
    ///
    /// The weight sits beside each name because it is half the information: a 55 in a domain worth 15%
    /// of the score and a 55 in one worth 28% are not the same finding.
    private var domainsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("0").font(AgeDesign.ui(10)).foregroundStyle(AuraPalette.textDim)
                Spacer()
                Text("50").font(AgeDesign.ui(10)).foregroundStyle(AuraPalette.textDim)
                Spacer()
                Text("100").font(AgeDesign.ui(10)).foregroundStyle(AuraPalette.textDim)
            }
            .padding(.bottom, 15)

            ForEach(Array(reading.domains.enumerated()), id: \.element.id) { index, domain in
                VStack(spacing: 0) {
                    HStack(spacing: 10) {
                        Text(domain.label)
                            .font(AgeDesign.ui(13))
                            .foregroundStyle(AuraPalette.textPrimary)
                        Spacer(minLength: 8)
                        HStack(alignment: .firstTextBaseline, spacing: 9) {
                            Text(String(localized: "\(domain.weight) of score"))
                                .font(AgeDesign.ui(11))
                                .foregroundStyle(AuraPalette.textQuiet)
                            Text(String(Int(domain.score.rounded())))
                                .font(AgeDesign.number(19, weight: .light))
                                .monospacedDigit()
                                .foregroundStyle(AuraPalette.textPrimary)
                                .frame(minWidth: 26, alignment: .trailing)
                        }
                    }
                    .padding(.bottom, 8)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(AuraPalette.track).frame(height: 5)
                            Capsule()
                                .fill(AgeDesign.ageGreen)
                                .frame(width: max(2, geo.size.width * min(max(domain.score, 0), 100) / 100), height: 5)
                        }
                    }
                    .frame(height: 5)

                    if index < reading.domains.count - 1 {
                        Color.clear.frame(height: 12)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(
                    Text("\(domain.label), \(Int(domain.score.rounded())) out of 100, \(domain.weight) of the score")
                )
            }

            Text(String(localized: "A domain is a 0–100 standing from a separate scorer. It is not a signed contribution to Body Age."))
                .font(AgeDesign.ui(11.5))
                .lineSpacing(3)
                .foregroundStyle(AuraPalette.textQuiet)
                .padding(.top, 14)
        }
        .padding(16)
        .background(ageCard(radius: 24))
    }

    private var domainsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(String(localized: "Health domains"))
                    .font(AgeDesign.ui(10, weight: .semibold))
                    .tracking(1.4)
                    .textCase(.uppercase)
                    .foregroundStyle(AuraPalette.textFaint)
                Spacer()
                if !reading.domainsNote.isEmpty {
                    Text(reading.domainsNote)
                        .font(AgeDesign.ui(10.5))
                        .foregroundStyle(AuraPalette.textDim)
                        .multilineTextAlignment(.trailing)
                }
            }
            .padding(.horizontal, 2)

            if reading.domains.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("—")
                        .font(AgeDesign.number(34, weight: .ultraLight))
                        .foregroundStyle(AuraPalette.textDim)
                    Text(String(localized: "Not enough instruments to score the health domains yet."))
                        .font(AgeDesign.ui(13))
                        .lineSpacing(4)
                        .foregroundStyle(AuraPalette.textSecondary)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(ageCard(radius: 24))
            } else {
                domainsCard
            }
        }
    }

    /// Fine print, drawn as fine print.
    ///
    /// This used `AuraInfoBanner`, which fills its background with the colour it is handed and draws
    /// near-black text on top — it exists to make one sentence unmissable, and it is correct on Today,
    /// where it carries the day's read in full accent cyan. Handing it a muted grey produced a pale slab
    /// of dark-on-grey text sitting under a dark screen: the loudest element on the page was its
    /// disclaimer, and the contrast was poor in the bargain.
    private var disclaimer: some View {
        Text(reading.disclaimer)
            .font(AgeDesign.ui(11))
            .lineSpacing(3)
            .foregroundStyle(AuraPalette.textDim)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 2)
            .padding(.top, 2)
    }

    // MARK: Drivers

    private var driversCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(String(localized: "What's moving it"))
                    .font(AgeDesign.ui(10, weight: .semibold))
                    .tracking(1.4)
                    .textCase(.uppercase)
                    .foregroundStyle(AuraPalette.textFaint)
                Spacer()
                Text(reading.driversNote)
                    .font(AgeDesign.ui(11))
                    .foregroundStyle(AuraPalette.textDim)
            }
            .padding(.horizontal, 2)

            VStack(alignment: .leading, spacing: 11) {
                HStack {
                    Text(String(localized: "← takes years off"))
                        .font(AgeDesign.ui(10, weight: .semibold))
                        .tracking(0.6)
                        .textCase(.uppercase)
                        .foregroundStyle(AgeDesign.mint)
                    Spacer()
                    Text(String(localized: "adds years →"))
                        .font(AgeDesign.ui(10, weight: .semibold))
                        .tracking(0.6)
                        .textCase(.uppercase)
                        .foregroundStyle(AgeDesign.adverse)
                }

                if reading.drivers.isEmpty {
                    Text(String(localized: "The exact driver snapshot is unavailable for this stored week."))
                        .font(AgeDesign.ui(13))
                        .lineSpacing(4)
                        .foregroundStyle(AuraPalette.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
                } else {
                    ForEach(reading.drivers) { driver in
                        driverRow(driver)
                    }
                }

                Text(String(localized: "Each row is the model's stored signed contribution for that factor. The rows are not recomputed from today's data."))
                    .font(AgeDesign.ui(11.5))
                    .lineSpacing(3)
                    .foregroundStyle(AuraPalette.textQuiet)
            }
            .padding(16)
            .background(ageCard(radius: 24))
        }
    }

    /// A signed contribution, drawn as a bar that leaves centre in the direction it pushes. Direction is
    /// carried by the label and the side the bar sits on, never by colour alone — a wearer who cannot
    /// separate the two hues still reads "adds years" / "takes years off" from the text.
    private func driverRow(_ driver: AuraAgeReading.Driver) -> some View {
        HStack(spacing: 10) {
            Text(driver.label)
                .font(AgeDesign.ui(12.5))
                .lineLimit(2)
                .foregroundStyle(AuraPalette.textSecondary)
                .frame(width: 98, alignment: .leading)

            GeometryReader { geo in
                let half = geo.size.width / 2
                let width = max(2, half * min(max(driver.magnitude, 0), 1))
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.white.opacity(0.16))
                        .frame(width: 1, height: 20)
                        .offset(x: half)
                    Capsule()
                        .fill(driver.isProtective ? AgeDesign.ageGreen : AgeDesign.adverse)
                        .frame(width: width, height: 5)
                        .offset(x: driver.isProtective ? half - width : half)
                }
                .frame(maxHeight: .infinity, alignment: .center)
            }
            .frame(height: 20)

            Text(driver.effect)
                .font(AgeDesign.ui(11.5, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(driver.isProtective ? AgeDesign.mint : AgeDesign.adverse)
                .frame(width: 51, alignment: .trailing)
        }
        .frame(minHeight: 34)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(driver.label), \(driver.effect)"))
    }

    // MARK: Trend

    private var trendCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(String(localized: "Body Age over time"))
                    .font(AgeDesign.ui(10, weight: .semibold))
                    .tracking(1.4)
                    .textCase(.uppercase)
                    .foregroundStyle(AuraPalette.textFaint)
                Spacer()
                Text(historyDelta)
                    .font(AgeDesign.ui(11, weight: .semibold))
                    .foregroundStyle(historyDeltaTint)
            }
            .padding(.bottom, 16)

            AuraTrendChart(
                values: reading.history,
                labels: reading.historyLabels,
                selected: max(reading.history.count - 1, 0),
                window: reading.historyWindow,
                onSelect: { _ in }
            )
            .frame(height: 112)
            .allowsHitTesting(false)

            HStack {
                ForEach(historyAxis, id: \.self) { label in
                    Text(label)
                        .font(AgeDesign.ui(10.5))
                        .foregroundStyle(AuraPalette.textDim)
                    if label != historyAxis.last { Spacer(minLength: 4) }
                }
            }
            .padding(.top, 8)

            Text(historyNote)
                .font(AgeDesign.ui(11.5))
                .lineSpacing(3)
                .foregroundStyle(AuraPalette.textQuiet)
                .padding(.top, 12)
        }
        .padding(16)
        .background(ageCard(radius: 24))
    }

    private var historyDelta: String {
        guard let first = reading.history.first, let last = reading.history.last, reading.history.count > 1 else {
            return String(localized: "Starting point")
        }
        return String(format: "%+.1f yr", last - first)
    }

    private var historyDeltaTint: Color {
        guard let first = reading.history.first, let last = reading.history.last else { return AuraPalette.textDim }
        if abs(last - first) < 0.05 { return AuraPalette.textQuiet }
        return last < first ? AgeDesign.mint : AgeDesign.adverse
    }

    private var historyAxis: [String] {
        guard !reading.historyLabels.isEmpty else { return [] }
        let last = reading.historyLabels.count - 1
        let indexes = [0, last / 3, last * 2 / 3, last]
        var seen = Set<Int>()
        return indexes.compactMap { seen.insert($0).inserted ? reading.historyLabels[$0] : nil }
    }

    private var historyNote: String {
        reading.history.count < 4
            ? String(localized: "There are \(reading.history.count) weekly snapshots. Treat this as a starting point, not a trend.")
            : String(localized: "Each point is one stored weekly Body Age. Noop does not fill missing weeks or draw a confidence ribbon the model did not provide.")
    }

    // MARK: Fitness Age + VO₂max

    private var fitnessCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .firstTextBaseline) {
                Text(String(localized: "A different question"))
                    .font(AgeDesign.ui(10, weight: .semibold))
                    .tracking(1.4)
                    .textCase(.uppercase)
                    .foregroundStyle(AuraPalette.textFaint)
                Spacer()
                Text(reading.fitnessNote)
                    .font(AgeDesign.ui(10.5))
                    .foregroundStyle(AuraPalette.textDim)
            }

            HStack(spacing: 9) {
                ageStat(
                    label: String(localized: "Fitness Age"),
                    value: reading.fitnessAge,
                    unit: reading.fitnessAgeUnit
                )
                ageStat(
                    label: String(localized: "VO₂ max"),
                    value: reading.vo2max,
                    unit: reading.vo2maxUnit
                )
            }

            Text(reading.fitnessCaveat)
                .font(AgeDesign.ui(11.5))
                .lineSpacing(3)
                .foregroundStyle(AuraPalette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(ageCard(radius: 24))
    }

    private func ageStat(label: String, value: String, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(AgeDesign.ui(10, weight: .semibold))
                .tracking(1)
                .textCase(.uppercase)
                .foregroundStyle(Color(hex: "#A9B4E0"))
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(value)
                    .font(AgeDesign.number(34, weight: .ultraLight))
                    .monospacedDigit()
                    .foregroundStyle(value == "—" ? AuraPalette.textDim : AuraPalette.textPrimary)
                if !unit.isEmpty {
                    Text(unit)
                        .font(AgeDesign.ui(10.5))
                        .foregroundStyle(AuraPalette.textTertiary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
            }
        }
        .padding(13)
        .frame(maxWidth: .infinity, minHeight: 86, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AuraPalette.rest.opacity(0.07))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(AuraPalette.rest.opacity(0.22), lineWidth: 0.5)
                }
        )
        .accessibilityElement(children: .combine)
    }

    // MARK: Not ready

    /// The readiness path is the one most likely to be seen on a fresh install, so it gets the same care
    /// as the ready one: what is missing, whether it blocks the number, and how far off it is.
    private var notReadyCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(String(localized: "What is needed"))
                    .font(AgeDesign.ui(10, weight: .semibold))
                    .tracking(1.4)
                    .textCase(.uppercase)
                    .foregroundStyle(AuraPalette.textFaint)
                Spacer()
                Text(reading.readinessNote)
                    .font(AgeDesign.ui(11))
                    .foregroundStyle(AuraPalette.textDim)
            }
            .padding(.bottom, 8)

            Text(reading.readinessLead)
                .font(AgeDesign.ui(14.5))
                .lineSpacing(4)
                .foregroundStyle(AuraPalette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 16)

            ForEach(Array(reading.readiness.enumerated()), id: \.element.id) { index, item in
                AuraListRow(key: item.label,
                            value: item.statusText,
                            subtitle: item.detail.isEmpty ? nil : item.detail,
                            showsDivider: index < reading.readiness.count - 1)
            }
        }
        .padding(16)
        .background(ageCard(radius: 24))
    }

    private var notReadyHero: some View {
        VStack(spacing: 10) {
            BodyAgeAura(value: "—", available: false, reduceMotion: true)
                .frame(width: 178, height: 178)
            Text(String(localized: "Not enough yet"))
                .font(AgeDesign.number(28, weight: .light))
                .foregroundStyle(AuraPalette.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var readCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(String(localized: "The read"))
                .font(AgeDesign.ui(10, weight: .semibold))
                .tracking(1.4)
                .textCase(.uppercase)
                .foregroundStyle(AgeDesign.mint)
            Text(reading.read)
                .font(AgeDesign.ui(13.5))
                .lineSpacing(5)
                .foregroundStyle(Color(hex: "#D2E2D8"))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(hex: "#14201B"))
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(AgeDesign.ageGreen.opacity(0.22), lineWidth: 0.5)
                }
        )
    }

    private func ageCard(radius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(AuraPalette.card)
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(AuraPalette.cardBorder, lineWidth: 0.5)
            }
    }
}

// MARK: - Handoff graphic

private enum AgeDesign {
    static let ageGreen = Color(hex: "#2ECC80")
    static let mint = Color(hex: "#8FEFC0")
    static let adverse = Color(hex: "#F3C888")

    static func number(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom("Outfit", size: size).weight(weight)
    }

    static func ui(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom("Instrument Sans", size: size).weight(weight)
    }
}

private struct BodyAgeAura: View {
    let value: String
    let available: Bool
    let reduceMotion: Bool

    @State private var breathing = false
    @State private var spinning = false

    private var tint: Color { available ? AgeDesign.ageGreen : AuraPalette.textDim }

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [tint.opacity(available ? 0.30 : 0.13), tint.opacity(0)],
                            center: .center,
                            startRadius: 0,
                            endRadius: side * 0.58
                        )
                    )
                    .frame(width: side * 1.16, height: side * 1.16)
                    .blur(radius: side * 0.075)
                    .scaleEffect(breathing ? 1.04 : 0.97)

                BodyAgeBlobShape()
                    .fill(
                        RadialGradient(
                            stops: [
                                .init(color: Color(hex: "#080B0A"), location: 0),
                                .init(color: Color(hex: "#080B0A"), location: 0.30),
                                .init(color: tint.opacity(0.10), location: 0.40),
                                .init(color: tint.opacity(0.38), location: 0.56),
                                .init(color: tint.opacity(0.82), location: 0.72),
                                .init(color: available ? Color(hex: "#9EF0CC").opacity(0.42) : tint.opacity(0.20), location: 0.86),
                                .init(color: tint.opacity(0), location: 1),
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: side * 0.50
                        )
                    )
                    .frame(width: side * 0.92, height: side * 0.92)
                    .blur(radius: side * 0.022)
                    .rotationEffect(.degrees(breathing ? 5 : -4))

                BodyAgeBlobShape()
                    .fill(
                        RadialGradient(
                            colors: [Color.clear, tint.opacity(available ? 0.16 : 0.08), Color.clear],
                            center: .center,
                            startRadius: side * 0.16,
                            endRadius: side * 0.48
                        )
                    )
                    .frame(width: side * 0.98, height: side * 0.98)
                    .blur(radius: side * 0.045)
                    .rotationEffect(.degrees(breathing ? -8 : 7))

                if available {
                    BodyAgeSpecks()
                        .frame(width: side * 0.90, height: side * 0.90)
                        .rotationEffect(.degrees(spinning ? 360 : 0))
                }

                Text(value)
                    .font(AgeDesign.number(side * 0.29, weight: .ultraLight))
                    .tracking(-1.2)
                    .monospacedDigit()
                    .foregroundStyle(available ? AuraPalette.textPrimary : AuraPalette.textDim)
                    .shadow(color: .black.opacity(0.6), radius: 13, y: 2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                breathing = true
            }
            withAnimation(.linear(duration: 60).repeatForever(autoreverses: false)) {
                spinning = true
            }
        }
        .accessibilityHidden(true)
    }
}

private struct BodyAgeBlobShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.025))
        path.addCurve(
            to: CGPoint(x: rect.maxX - rect.width * 0.04, y: rect.midY - rect.height * 0.04),
            control1: CGPoint(x: rect.maxX - rect.width * 0.12, y: rect.minY),
            control2: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.28)
        )
        path.addCurve(
            to: CGPoint(x: rect.midX + rect.width * 0.02, y: rect.maxY - rect.height * 0.02),
            control1: CGPoint(x: rect.maxX - rect.width * 0.01, y: rect.maxY - rect.height * 0.19),
            control2: CGPoint(x: rect.maxX - rect.width * 0.23, y: rect.maxY)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.05, y: rect.midY + rect.height * 0.03),
            control1: CGPoint(x: rect.minX + rect.width * 0.25, y: rect.maxY),
            control2: CGPoint(x: rect.minX, y: rect.maxY - rect.height * 0.25)
        )
        path.addCurve(
            to: CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.025),
            control1: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.25),
            control2: CGPoint(x: rect.minX + rect.width * 0.23, y: rect.minY)
        )
        path.closeSubpath()
        return path
    }
}

private struct BodyAgeSpecks: View {
    private static let points: [(CGFloat, CGFloat, CGFloat, Double)] = [
        (0.17,0.25,1.4,0.72),(0.28,0.12,0.9,0.45),(0.42,0.08,1.3,0.70),(0.59,0.12,0.9,0.55),
        (0.73,0.18,1.6,0.75),(0.84,0.31,1.0,0.50),(0.90,0.47,1.4,0.62),(0.82,0.63,0.8,0.48),
        (0.75,0.79,1.5,0.72),(0.59,0.88,1.0,0.57),(0.43,0.91,1.7,0.74),(0.29,0.82,0.9,0.50),
        (0.16,0.72,1.4,0.66),(0.10,0.55,0.9,0.54),(0.12,0.38,1.7,0.78),(0.34,0.27,0.7,0.50),
        (0.65,0.27,0.8,0.55),(0.71,0.47,1.0,0.62),(0.58,0.70,0.8,0.50),(0.35,0.67,1.0,0.58),
    ]

    var body: some View {
        Canvas { context, size in
            for point in Self.points {
                let radius = point.2
                let rect = CGRect(
                    x: size.width * point.0 - radius,
                    y: size.height * point.1 - radius,
                    width: radius * 2,
                    height: radius * 2
                )
                context.fill(Path(ellipseIn: rect), with: .color(AgeDesign.mint.opacity(point.3)))
            }
        }
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

    #if DEBUG
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
    #endif
}
#endif
