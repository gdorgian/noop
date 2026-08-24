#if os(iOS)
import SwiftUI
import StrandDesign

// MARK: - Aura Trends
//
// The only screen where a chart is the point. Even so it closes with "the read" — a paragraph that says
// what the shape means — because a line going up is not, on its own, an instruction.

struct AuraTrendsView: View {
    private let reading: AuraTrendsReading
    /// Trends is where a multi-week view belongs, so the two age readings hang off it rather than
    /// taking one of the five tab slots.
    private let onOpenAge: () -> Void

    @State private var range: AuraTrendsReading.Range = .sixWeeks
    /// Which point the crosshair sits on. `nil` = the latest, which is where every range should open.
    @State private var point: Int?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var motion = NoopMotionState.shared

    private var poseStill: Bool { motion.poseStill(reduceMotion) }

    init(reading: AuraTrendsReading, onOpenAge: @escaping () -> Void = {}) {
        self.reading = reading
        self.onOpenAge = onOpenAge
    }

    private var series: AuraTrendsReading.Series { reading.series(for: range) }

    private var selectedIndex: Int {
        guard let point, series.values.indices.contains(point) else {
            return max(series.values.count - 1, 0)
        }
        return point
    }

    var body: some View {
        VStack(spacing: AuraPalette.cardGap) {
            AuraSegmentedChips(
                // Labelled explicitly so the tuple matches the parameter's labelled element type
                // without relying on an implicit conversion inside generic inference.
                options: AuraTrendsReading.Range.allCases.map { (value: $0, label: $0.label) },
                selection: range
            ) { newRange in
                withAnimation(NoopMotion.gated(NoopMotion.value, reduced: poseStill)) {
                    range = newRange
                    // A new range has a different point count, so an index from the old one is meaningless.
                    point = nil
                }
            }

            chargeCard
            overviewCard
            signalsCard
            debtCard
            ageRow
            AuraReadCard(overline: String(localized: "The read"), text: series.read)
        }
    }

    /// The door to Body Age and Fitness Age. Deliberately a row, not a number: those readings update
    /// weekly, and putting a stale-by-design figure among the daily charts above would invite reading it
    /// as today's.
    private var ageRow: some View {
        VStack(spacing: 0) {
            AuraListRow(key: String(localized: "Your ages"),
                        subtitle: String(localized: "Body Age, Fitness Age and the VO₂max behind them"),
                        showsDivider: false,
                        action: onOpenAge)
        }
        .padding(.horizontal, 16)
        .auraCard()
    }

    private var overviewCard: some View {
        HStack(spacing: 8) {
            AuraStatTile(label: String(localized: "30-day avg Charge"),
                         value: reading.averageCharge, unit: "%", valueTint: AuraPalette.accent)
            AuraStatTile(label: String(localized: "30-day avg sleep"),
                         value: reading.averageSleep, unit: "h", valueTint: AuraPalette.rest)
        }
    }

    private var signalsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            AuraCardHeader(title: String(localized: "Last 30 days"),
                           note: String(localized: "Latest · personal data"))
                .padding(.horizontal, 2)
                .padding(.bottom, 10)
            ForEach(Array(reading.metrics.enumerated()), id: \.element.id) { index, metric in
                HStack(spacing: 12) {
                    Image(systemName: metric.symbol)
                        .font(.system(size: 16))
                        .foregroundStyle(metric.tint)
                        .frame(width: 22)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(metric.name)
                            .font(.system(size: 12))
                            .foregroundStyle(AuraPalette.textQuiet)
                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            Text(metric.value)
                                .font(.system(size: 18, design: .rounded).monospacedDigit())
                                .foregroundStyle(AuraPalette.textPrimary)
                            Text(metric.unit)
                                .font(.system(size: 11.5))
                                .foregroundStyle(AuraPalette.textFaint)
                        }
                    }
                    Spacer(minLength: 8)
                    Sparkline(
                        values: metric.series,
                        gradient: Gradient(colors: [metric.tint, metric.tint]),
                        lineWidth: 1.7,
                        showsArea: false,
                        showsHead: true,
                        showsHover: false
                    )
                    .frame(width: 88, height: 30)
                    .accessibilityHidden(true)
                }
                .frame(minHeight: 61)
                .accessibilityElement(children: .combine)
                if index < reading.metrics.count - 1 {
                    Rectangle().fill(AuraPalette.cardBorder).frame(height: 0.5)
                }
            }
        }
        .padding(18)
        .auraCard()
    }

    // MARK: Charge

    private var chargeCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            AuraCardHeader(title: String(localized: "Charge"),
                           note: series.chargeNote)
                .padding(.bottom, 20)

            Group {
                if series.values.isEmpty {
                    Text(String(localized: "No Charge readings in this range."))
                        .font(.system(size: 13.5))
                        .foregroundStyle(AuraPalette.textQuiet)
                        .frame(maxWidth: .infinity, minHeight: 140, alignment: .center)
                } else {
                    AuraTrendChart(values: series.values, labels: series.labels, selected: selectedIndex,
                                   window: 0...100, normalRange: series.normalRange) { hit in
                        point = hit
                    }
                }
            }
            .padding(.bottom, 10)

            HStack {
                ForEach(series.axis, id: \.self) { label in
                    Text(label)
                        .font(.system(size: 10.5))
                        .foregroundStyle(AuraPalette.textDim)
                    if label != series.axis.last { Spacer(minLength: 4) }
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 19)
        .padding(.bottom, 15)
        .auraCard()
    }

    // MARK: Rest debt

    private var debtCard: some View {
        VStack(spacing: 18) {
            AuraCardHeader(title: String(localized: "Rest debt"),
                           note: reading.debtVerdict,
                           noteTint: AuraPalette.rest)
            if reading.debt.isEmpty {
                Text(String(localized: "No nights with sleep data yet."))
                    .font(.system(size: 13.5))
                    .foregroundStyle(AuraPalette.textQuiet)
                    .frame(maxWidth: .infinity, minHeight: 82, alignment: .center)
            } else {
                AuraDebtBars(values: reading.debt)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 19)
        .padding(.bottom, 16)
        .auraCard()
    }
}

// MARK: - Reading

struct AuraTrendsReading {
    struct Metric: Identifiable {
        let id: String
        let name: String
        let value: String
        let unit: String
        let symbol: String
        let tint: Color
        let series: [Double]
    }

    enum Range: String, CaseIterable, Identifiable, Hashable {
        case sixWeeks
        case sixMonths
        case year

        var id: String { rawValue }

        var label: String {
            switch self {
            case .sixWeeks:  return String(localized: "6 weeks")
            case .sixMonths: return String(localized: "6 months")
            case .year:      return String(localized: "1 year")
            }
        }
    }

    struct Series {
        let values: [Double]
        /// One label per point, shown in the crosshair bubble.
        let labels: [String]
        /// Four evenly-spaced axis ticks.
        let axis: [String]
        let read: String
        /// The wearer's trailing-30-day middle 50% Charge range.
        let normalRange: ClosedRange<Double>?
        let chargeNote: String
    }

    let sixWeeks: Series
    let sixMonths: Series
    let year: Series
    let debt: [Double]
    let debtVerdict: String
    let headline: String
    let averageCharge: String
    let averageSleep: String
    let metrics: [Metric]

    func series(for range: Range) -> Series {
        switch range {
        case .sixWeeks:  return sixWeeks
        case .sixMonths: return sixMonths
        case .year:      return year
        }
    }

    #if DEBUG
    static let prototype = AuraTrendsReading(
        sixWeeks: Series(
            values: [62, 71, 58, 49, 66, 74, 81, 77, 64, 55, 68, 79, 84, 88],
            labels: ["3 Aug", "4 Aug", "5 Aug", "6 Aug", "7 Aug", "8 Aug", "9 Aug",
                     "10 Aug", "11 Aug", "12 Aug", "13 Aug", "14 Aug", "15 Aug",
                     String(localized: "Today")],
            axis: ["3 Aug", "7 Aug", "11 Aug", String(localized: "Today")],
            read: String(localized: "Two weeks of steady climbing, and the last three days are your best of the month. You’ve earned a hard session — take it today, not Monday."),
            normalRange: 58...76,
            chargeNote: String(localized: "Your normal 58–76")
        ),
        sixMonths: Series(
            values: [48, 55, 61, 52, 44, 58, 66, 71, 63, 57, 49, 62, 70, 78, 74, 66, 59, 68, 75, 82, 88],
            labels: ["Wk 1", "Wk 1", "Wk 1", "Wk 1", "Wk 2", "Wk 2", "Wk 2", "Wk 2",
                     "Wk 3", "Wk 3", "Wk 3", "Wk 3", "Wk 3", "Wk 4", "Wk 4", "Wk 4",
                     "Wk 4", "Wk 5", "Wk 5", "Wk 5", String(localized: "Today")],
            axis: ["18 Jul", "26 Jul", "4 Aug", String(localized: "Today")],
            read: String(localized: "The dip mid-month was three short nights, not training. Once sleep came back, so did everything else."),
            normalRange: 56...75,
            chargeNote: String(localized: "Your normal 56–75")
        ),
        year: Series(
            values: [40, 46, 52, 49, 58, 63, 57, 51, 62, 70, 66, 59, 68, 74, 71, 65, 72, 79, 84, 88],
            labels: ["May", "May", "May", "Jun", "Jun", "Jun", "Jun", "Jun",
                     "Jul", "Jul", "Jul", "Jul", "Jul", "Aug", "Aug", "Aug",
                     "Aug", "Aug", "Aug", String(localized: "Today")],
            axis: ["19 May", "18 Jun", "18 Jul", String(localized: "Today")],
            read: String(localized: "Up 18 points since May with fewer swings. Whatever you changed in June, keep doing it."),
            normalRange: 55...74,
            chargeNote: String(localized: "Your normal 55–74")
        ),
        debt: [0.4, 1.1, 0.2, 1.8, 2.4, 1.2, 0.6, 0, 0.9, 1.6, 0.8, 0.3, 0, 0],
        debtVerdict: String(localized: "Clear for 2 days"),
        headline: String(localized: "Where you’re trending"),
        averageCharge: "68",
        averageSleep: "6.8",
        metrics: [
            Metric(id: "hrv", name: String(localized: "Variability"), value: "56", unit: "ms",
                   symbol: "waveform.path.ecg", tint: AuraPalette.accent,
                   series: [44, 48, 46, 51, 49, 54, 53, 56]),
            Metric(id: "rhr", name: String(localized: "Resting heart rate"), value: "58", unit: "bpm",
                   symbol: "heart", tint: AuraPalette.effort,
                   series: [61, 60, 62, 59, 58, 59, 58]),
            Metric(id: "resp", name: String(localized: "Breathing"), value: "14.2", unit: "rpm",
                   symbol: "lungs", tint: AuraPalette.rest,
                   series: [14.5, 14.2, 14.3, 14.1, 14.2]),
            Metric(id: "sleep", name: String(localized: "Sleep"), value: "7.2", unit: "h",
                   symbol: "moon", tint: AuraPalette.rest,
                   series: [5.5, 7.3, 5.5, 6.1, 7.0, 6.6, 7.2]),
        ]
    )
    #endif
}
#endif
