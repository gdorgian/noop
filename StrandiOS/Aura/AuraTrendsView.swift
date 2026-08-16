#if os(iOS)
import SwiftUI
import StrandDesign

// MARK: - Aura Trends
//
// The only screen where a chart is the point. Even so it closes with "the read" — a paragraph that says
// what the shape means — because a line going up is not, on its own, an instruction.

struct AuraTrendsView: View {
    private let reading: AuraTrendsReading

    @State private var range: AuraTrendsReading.Range = .fortnight
    /// Which point the crosshair sits on. `nil` = the latest, which is where every range should open.
    @State private var point: Int?

    init(reading: AuraTrendsReading = .prototype) {
        self.reading = reading
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
                withAnimation(NoopMotion.value) {
                    range = newRange
                    // A new range has a different point count, so an index from the old one is meaningless.
                    point = nil
                }
            }

            chargeCard
            debtCard
            AuraReadCard(overline: String(localized: "The read"), text: series.read)
        }
    }

    // MARK: Charge

    private var chargeCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            AuraCardHeader(title: String(localized: "Charge"),
                           note: String(localized: "Band is your own normal"))
                .padding(.bottom, 20)

            AuraTrendChart(values: series.values, labels: series.labels, selected: selectedIndex) { hit in
                point = hit
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
            AuraDebtBars(values: reading.debt)
        }
        .padding(.horizontal, 18)
        .padding(.top, 19)
        .padding(.bottom, 16)
        .auraCard()
    }
}

// MARK: - Reading

struct AuraTrendsReading {
    enum Range: String, CaseIterable, Identifiable, Hashable {
        case fortnight
        case month
        case quarter

        var id: String { rawValue }

        var label: String {
            switch self {
            case .fortnight: return String(localized: "14 days")
            case .month:     return String(localized: "30 days")
            case .quarter:   return String(localized: "3 months")
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
    }

    let fortnight: Series
    let month: Series
    let quarter: Series
    let debt: [Double]
    let debtVerdict: String

    func series(for range: Range) -> Series {
        switch range {
        case .fortnight: return fortnight
        case .month:     return month
        case .quarter:   return quarter
        }
    }

    static let prototype = AuraTrendsReading(
        fortnight: Series(
            values: [62, 71, 58, 49, 66, 74, 81, 77, 64, 55, 68, 79, 84, 88],
            labels: ["3 Aug", "4 Aug", "5 Aug", "6 Aug", "7 Aug", "8 Aug", "9 Aug",
                     "10 Aug", "11 Aug", "12 Aug", "13 Aug", "14 Aug", "15 Aug",
                     String(localized: "Today")],
            axis: ["3 Aug", "7 Aug", "11 Aug", String(localized: "Today")],
            read: String(localized: "Two weeks of steady climbing, and the last three days are your best of the month. You’ve earned a hard session — take it today, not Monday.")
        ),
        month: Series(
            values: [48, 55, 61, 52, 44, 58, 66, 71, 63, 57, 49, 62, 70, 78, 74, 66, 59, 68, 75, 82, 88],
            labels: ["Wk 1", "Wk 1", "Wk 1", "Wk 1", "Wk 2", "Wk 2", "Wk 2", "Wk 2",
                     "Wk 3", "Wk 3", "Wk 3", "Wk 3", "Wk 3", "Wk 4", "Wk 4", "Wk 4",
                     "Wk 4", "Wk 5", "Wk 5", "Wk 5", String(localized: "Today")],
            axis: ["18 Jul", "26 Jul", "4 Aug", String(localized: "Today")],
            read: String(localized: "The dip mid-month was three short nights, not training. Once sleep came back, so did everything else.")
        ),
        quarter: Series(
            values: [40, 46, 52, 49, 58, 63, 57, 51, 62, 70, 66, 59, 68, 74, 71, 65, 72, 79, 84, 88],
            labels: ["May", "May", "May", "Jun", "Jun", "Jun", "Jun", "Jun",
                     "Jul", "Jul", "Jul", "Jul", "Jul", "Aug", "Aug", "Aug",
                     "Aug", "Aug", "Aug", String(localized: "Today")],
            axis: ["19 May", "18 Jun", "18 Jul", String(localized: "Today")],
            read: String(localized: "Up 18 points since May with fewer swings. Whatever you changed in June, keep doing it.")
        ),
        debt: [0.4, 1.1, 0.2, 1.8, 2.4, 1.2, 0.6, 0, 0.9, 1.6, 0.8, 0.3, 0, 0],
        debtVerdict: String(localized: "Clear for 2 days")
    )
}
#endif
